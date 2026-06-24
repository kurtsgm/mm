# M2「資料驅動地圖」— 設計

- **日期**：2026-06-24
- **狀態**：設計已核可，待產出實作計畫
- **上游**：總架構設計 `docs/superpowers/specs/2026-06-24-mm3-style-blobber-architecture-design.md`（定義 M1–M5）
- **前一里程碑**：M1「走得動」已完成併入 `main`

## 目標

把 M1 寫死的地圖（`content/maps/test_map.gd` 的 `TestMap`，GDScript 程式產生 `GridData`）換成**資料驅動**：用純文字檔編寫地圖 → 解析成 `MapData` Resource → 引擎產生走位用的 `GridData`、呈現層產生幾何。完成後「加一張地圖 = 加一個資料檔，不碰引擎程式碼」這個核心不變式首次成立。

引擎層維持純邏輯、可單元測試（TDD）；呈現層靠手動／輕整合驗證。

## 範圍決策（為何是這個範圍）

總架構把 M2 列為「`MapData` Resource + `MapManager`，並把 `WorldBuilder` 的方塊換成 `GridMap` + `MeshLibrary`」。本設計**刻意把 `GridMap` + `MeshLibrary` 延後**，理由：

- 總架構同時把「美術風格定調與素材正式產製」列為本階段**非目標**。沒有真 3D 磚塊素材前，`GridMap` 只能配 placeholder primitive `MeshLibrary`——那是「先做一版、之後會被丟掉」的白工。
- `GridMap` 是 Godot 場景節點，不利於沿用 M1 的純邏輯單元測試流程。
- M2 的**實質價值**在「地圖從資料載入」這件事，與 `GridMap` 無關。把它做扎實又全程可測，才是這個里程碑的本質。

因此 M2 = **資料層 + 載入服務 + 把既有 procedural 幾何改成資料驅動**。`MapData` 的 schema 預留 `DOOR / STAIRS` 型別，未來補 `GridMap`（內容期）或樓梯換圖（約 M3 前後）都是加法，不需回頭改資料結構。

## 地圖編寫方式決策

地圖以**純文字 ASCII 檔**編寫，由 `MapAsciiImporter` 解析成 `MapData`。理由：手改快、diff 友善、parser 是純邏輯可 TDD。`MapData` 仍是 Godot `Resource`，所以未來存檔系統以 id 參照地圖、或做 in-editor 地圖清單都不受影響。M2 在執行時解析 `.txt` 得到記憶體中的 `MapData`；**不**提交 `.tres`（避免 txt/tres 兩套來源漂移）。日後若需要 in-editor 編輯或預匯入，再把 importer 的輸出存成 `.tres` 即可，是 trivial 追加。

## 資料流

```
content/maps/level01.txt          （人類編寫來源，純文字）
        │  MapAsciiImporter.parse(text) -> MapData        ← 純邏輯，TDD
        ▼
   MapData (Resource)              map_id, width, height, tiles[], start_pos, start_facing
        │                          + enum TileType
        │
   MapManager.load_text/load_text_file(...)               ← autoload，薄協調層
        ├──────────────────────► WorldBuilder.build(MapData)   ← 依 tile 型別畫 地板/牆/門/樓梯
        │                                                         （placeholder 方塊，非 GridMap）
        ▼
   MapBuilder.to_grid_data(MapData) -> GridData            ← 純邏輯，套可走規則，TDD
        │
        ▼
   PlayerController.setup(grid, start_pos, start_facing)   ← M1 既有，幾乎不動
```

## 三層歸屬

| 檔案 | 層 | 性質 |
|------|----|------|
| `resources/map_data.gd`（`class_name MapData extends Resource`） | content | 純資料 + `enum TileType { FLOOR, WALL, DOOR, STAIRS_UP, STAIRS_DOWN }`；只含資料欄位與 trivial accessor |
| `content/maps/level01.txt` | content | 文字地圖：重現 M1 的 7×7 佈局，外加至少 1 個 `DOOR`、1 處 `STAIRS` 以驗證新型別 |
| `engine/map/map_ascii_importer.gd`（`MapAsciiImporter`） | engine | 純解析 `text -> MapData`，可單元測試 |
| `engine/map/map_builder.gd`（`MapBuilder`） | engine | 純 `MapData -> GridData`，唯一掌握「哪種 tile 可走」的規則，可單元測試 |
| `autoload/map_manager.gd`（`MapManager`，autoload `Node`） | 服務 | 薄：持有 `current_map` / `current_grid`，提供 `load_text()` / `load_text_file()`；邏輯全委派給上述純類別 |
| `presentation/world/world_builder.gd`（修改） | presentation | 改吃 `MapData`、依型別畫不同 placeholder、修 carry-over |
| `presentation/world/main.gd`（修改） | presentation | 改成載入 `level01.txt`（經 `MapManager`）而非 `TestMap` |
| `presentation/world/world_builder_preview.*`（修改） | presentation | 改引用新載入路徑而非 `TestMap` |
| `content/maps/test_map.gd`（**刪除**） | — | 由 `level01.txt` 取代，避免兩套地圖來源 |

### 關鍵約束與刀法

- **引擎層既有檔完全不動**：`GridData`、`GridMovement`、`GridDirection`、`GridGeometry` 不修改，不必回頭重測。M2 是純加法（新增 `MapData`、`MapAsciiImporter`、`MapBuilder`）外加呈現層改接線。
- **依賴箭頭方向正確**：`TileType` enum 放在 `MapData`（content）上；`MapBuilder`（engine）反向引用 `MapData.TileType`——符合「engine 依賴 content 的資料結構」。content 不依賴任何層。
- **可走規則單一出處**：只有 `MapBuilder.is_walkable_type()` 知道型別→可走的對應（`WALL` 擋，`FLOOR/DOOR/STAIRS_*` 可走）。`GridData` 維持單純的 solid-cell 走位抽象。
- **MapManager 維持薄**：它是唯一碰檔案 IO 與全域狀態的點；所有可測邏輯都在 `MapAsciiImporter` / `MapBuilder`。提供 `load_text(text)` 以便不經檔案 IO 做整合測試。

## `MapData` 資料結構

```
class_name MapData extends Resource

enum TileType { FLOOR = 0, WALL = 1, DOOR = 2, STAIRS_UP = 3, STAIRS_DOWN = 4 }

var map_id: String
var width: int
var height: int
var tiles: PackedInt32Array        # 列優先，index = y * width + x，值為 TileType
var start_pos: Vector2i
var start_facing: int              # GridDirection.Dir，預設 NORTH

func get_tile(pos: Vector2i) -> int # 界外回傳 WALL（對齊 GridData 界外=solid 約定）
```

## ASCII 地圖格式

| 字元 | 意義 |
|------|------|
| `#` | 牆 `WALL` |
| `.` | 地板 `FLOOR` |
| `D` | 門 `DOOR`（M2 視為永遠可走、有視覺標記；不做開關狀態） |
| `<` | 上樓梯 `STAIRS_UP`（M2 為可走標記格，不觸發換圖） |
| `>` | 下樓梯 `STAIRS_DOWN`（同上） |
| `@` | 起點：該格內容為 `FLOOR`，並記錄 `start_pos`；起始面向預設 `NORTH` |

解析規則：

- 每列等長 → `width` = 列長、`height` = 列數；非矩形報錯。
- 上方為北（`y = 0`）、左為西（`x = 0`），與 M1 座標約定一致（北 = `-y`）。
- 恰好一個 `@`；零個或多個 → 報錯。
- 未知字元 → 報錯（不靜默當地板，以免地圖打錯沒發現）。
- 結尾空白列／行尾空白先行修剪。

範例（重現 M1 7×7 佈局，並加入門與樓梯示意）：

```
#######
#@.D..#
#..#..#
#..#.<#
#....##
#.#..>#
#######
```

> 確切佈局於實作計畫階段定案；原則是「與 M1 走位手感連續」＋「至少各出現一次 DOOR 與 STAIRS」。

## Placeholder 視覺（M2 不導入真素材）

- `WALL`：整格高方塊（沿用 M1 `WorldBuilder` 牆）。
- `FLOOR`：地板（沿用）。
- `DOOR`：矮一截、不同顏色的方塊，可穿過。
- `STAIRS_UP/DOWN`：地板上一個不同顏色的標記（斜方塊或小塊），可走；M2 不換圖。

`WorldBuilder.build(map: MapData)` 逐格依 `map.get_tile()` 決定畫哪種 placeholder。

## carry-over 修正（M2 早期處理）

`world_builder.gd` 的 `build()` 目前用 `child.queue_free()`（延遲釋放）清舊幾何。M1 只 build 一次所以無害，但 M2 會在換地圖時 rebuild → 同一幀 rebuild 會殘留舊牆。改為同步釋放：

```gdscript
for child in get_children():
    remove_child(child)
    child.free()
```

配一個測試：先 `build` 地圖 A、再用佈局不同的地圖 B `rebuild`，斷言子節點數對應 B（無殘留舊幾何）。

## 測試策略

沿用 GUT。引擎與解析層為純邏輯 → TDD：

- `tests/.../test_map_data.gd`：`get_tile`、界外→`WALL`、`width`/`height`。
- `tests/.../test_map_ascii_importer.gd`：解析正確（各型別位置、`start_pos`、`start_facing`）；錯誤情境（非矩形、無 `@`、多個 `@`、未知字元）。
- `tests/.../test_map_builder.gd`：`MapData -> GridData` 可走性（`WALL` solid、`DOOR`/`STAIRS_*`/`FLOOR` 可走、界外 solid）。
- `tests/presentation/test_world_builder.gd`（擴充）：carry-over——A→B rebuild 無殘留子節點。
- `MapManager`：以 `load_text(text)` 做一條輕整合測試（驗證 `current_map` / `current_grid` 設定正確），避免依賴檔案 IO。

呈現層（實際 3D 畫面、輸入手感）靠手動驗證，比照 M1。

## M2 完成定義（Definition of Done）

1. 全引擎層測試綠燈（既有 + 新增 `MapData` / `MapAsciiImporter` / `MapBuilder`），指令列可重現。
2. 遊戲從 `content/maps/level01.txt` 載入 → 畫出 地板/牆/門/樓梯 placeholder → 走位手感同 M1（牆擋下、門與樓梯可走）。
3. `WorldBuilder` carry-over 修好，且有測試證明 rebuild 不殘留。
4. 三層分離維持：`engine/` 無視覺節點依賴；`MapData` 是 `Resource`；地圖是資料檔；既有引擎四檔未改動。
5. `TestMap` 已刪除、引用全數改接 `level01.txt`。
6. 每個 Task 各自 commit。

## 非目標（M2 明確延後）

- `GridMap` + `MeshLibrary` 與真 3D 磚塊素材（內容期再做）。
- 地圖間樓梯換圖（自然落在 M3 前後）——M2 的樓梯只是可走標記格。
- 門的開關／鎖狀態。
- tile 上的事件、遭遇表、佔用者等額外語意（schema 之後再擴）。
- 真美術風格與素材。
