# M6 場景主題化貼圖 — 設計

- **日期**：2026-06-25
- **狀態**：設計待核可（spec review gate）
- **範圍**：場景外觀的資料驅動架構。把「場景幾何/外觀」從寫死在 `world_builder.gd` 的純色 `BoxMesh`，升級成「主題（theme）= 一套 3D 磚塊 kit」的資料驅動管線，讓多張地圖能各自分主題。不碰戰鬥/法術/存檔/移動邏輯。

## 目標

- 每張地圖能指定一個**主題**（洞窟/城堡/地牢…各一套外觀），換主題 = 換一個資料參照，零引擎程式碼改動。
- 沿用現有「整格 = 牆」的 `MapData` tile 模型，**不改 tile 資料模型**。
- 用 Godot 內建 **GridMap + MeshLibrary** 當渲染基底。
- 整條管線能在**不依賴任何外部素材**的情況下端對端驗證通過（用程式碼生成的 `default` 主題）。
- 素材來源：免費 CC0 / CC-BY 模組化 3D kit（Kenney、Quaternius、KayKit…），偏低多邊形 / stylized 風（免費資源量最大的一塊）。

## 非目標（本里程碑不做）

- 正式美術定調、實際下載/接上特定 kit（屬內容期；本里程碑只證明管線 + 留一份「如何接 kit」步驟文件）。
- 薄牆板 / 邊牆模型（Grimrock 式「兩格間一片薄牆」）。GridMap 一格一 mesh 與之衝突，屬之後另案。
- 主題的環境氛圍欄位（霧色、環境光色調、天空盒）。schema 預留擴充空間但本期不實作。
- 動態/可破壞場景、逐格不同裝飾的自動鋪排（autotile 16 變體）。

## 核心決策

| 層面 | 決定 | 理由 |
|------|------|------|
| 渲染基底 | Godot 內建 GridMap + MeshLibrary | 一格一 mesh、批次效率好、Godot-native、文件多 |
| 主題單位 | 一套模組化 3D kit（= 一個 MeshLibrary） | dungeon crawler 的 CC0 kit 最豐富，一次給齊幾何+貼圖+變化 |
| 牆的擺法 | 整格實心磚塊（filled-cell block） | 吻合現有「整格=牆」資料模型；GridMap 一格一 mesh 的自然用法；經典 blobber 外觀 |
| 主題宣告 | 地圖 ASCII 加可選 `theme:` header；缺省 = `default` | 主題與地圖同檔、就近可見；舊地圖無 header 仍可跑 |
| 預設主題 | 程式碼生成（彩色盒子 → MeshLibrary） | 管線可零素材驗證；保留現有外觀；kit 主題之後當資料檔疊加 |
| 授權 | CC0 / CC-BY（願標註來源） | 可選池更大；寫實風免費資源稀少，故走低多邊形 |

## 架構（三層分離，沿用既有風格）

### ① 資料層 — `DungeonTheme` Resource

新增 `resources/dungeon_theme.gd`（`class_name DungeonTheme extends Resource`）：

| 欄位 | 型別 | 說明 |
|------|------|------|
| `theme_id` | `String` | 主題識別字 |
| `mesh_library` | `MeshLibrary` | 該主題整套 3D 磚塊（kit 匯入產出，或留空=程式碼生成） |
| `item_for_tile` | `Dictionary` | `MapData.TileType（int）→ MeshLibrary item 名稱（String）` |
| `has_ceiling` | `bool` | 是否在地板格上方鋪天花板（室內開、洞窟可關），預設 `false` |
| `ceiling_item` | `String` | 天花板 item 名稱（`has_ceiling` 為真時用） |

- `item_for_tile` 用「item 名稱」而非 int id；`world_builder` 以 `MeshLibrary.find_item_by_name()` 解析成 int id。名稱比 id 穩定、可讀。
- `mesh_library` 為空代表程式碼生成主題（見 `default`）。

### ② 內容/解析 — 地圖主題宣告與 ThemeCatalog

**ASCII header 指令（`MapAsciiImporter` 擴充）**

地圖檔可在格子前放零或多行 `key: value` 指令；偵測規則：行符合 `^[a-z_]+:` 視為指令，否則視為格子起點。

```
theme: castle
#######
#@.D.<#
...
```

- 目前只認 `theme:`；其他 `key:` 指令**忽略**（保留未來擴充，如 `start_facing:`、`name:`）。
- 無 `theme:` header → `MapData.theme_id = "default"`（現有 `level01.txt` 不需改動即可跑）。
- 格子行永遠不含 `:`（合法 tile 字元為 `# . @ D < > a-z`），故指令偵測無歧義。

**`MapData` 新增欄位**：`@export var theme_id: String = "default"`。由 importer 從 header 設定。`theme_id` 屬靜態內容，**不進存檔**（存檔仍只記 `map_id`，載入時由 MapData 帶出 theme_id）→ 不動 save schema。

**`ThemeCatalog`**（新增 `presentation/world/theme_catalog.gd`，`class_name ThemeCatalog extends Object`）

比照現有 `Bestiary` / `ItemCatalog` / `SpellBook` 的小對照表模式：

- `get_theme(id: String) -> DungeonTheme`：
  - `id == "default"`（或查無）→ 回傳程式碼生成的 default 主題（見下）。
  - 其他 → `load()` 對應的 `.tres`。
- `has_theme(id) -> bool`、`all_ids() -> Array`。
- 內部 `const _THEMES := { "castle": "res://content/themes/castle.tres", ... }`（本期可空，default 之外不強制有資料）。

加一個新主題 = 丟一個 `DungeonTheme.tres` + 一個 MeshLibrary + 在 `_THEMES` 加一行。零引擎改動。

### ③ 呈現層 — `world_builder.gd` 改寫成驅動 GridMap

`build(map: MapData)` 介面**維持不變**（`main.gd` 的 `_ready()` / `_on_loaded()` 不用改）。內部改為：

1. `var theme := ThemeCatalog.get_theme(map.theme_id)`
2. 取得/重建一個 child `GridMap` 節點（`world_builder` 仍 `extends Node3D`，持有單一 child GridMap，rebuild 時清空 cells）。
3. `grid.mesh_library = theme.mesh_library`；`grid.cell_size = Vector3(2.0, 3.0, 2.0)`（X/Z = `GridGeometry.CELL_SIZE`；Y = `WALL_HEIGHT`，讓天花板剛好放上一層 y-index）。
4. 逐格 `grid.set_cell_item(Vector3i(x, 0, y), id)`：地板/牆/門/階梯各放 `item_for_tile` 對應 item。
5. `has_ceiling` 為真 → 在地板格上方 `Vector3i(x, 1, y)` 放 `ceiling_item`。

> GridMap 座標：用 `(x, 0, y)`（地圖 y 對到世界 Z）對齊既有 `GridGeometry.cell_to_world`（`Vector3(x*CELL, 0, y*CELL)`）。MeshLibrary item 的 mesh 以「地板面在 y=0、牆向上長到 `WALL_HEIGHT`」為基準（pivot 對齊），與現況幾何一致。

### 程式碼生成的 `default` 主題（保留現有外觀）

`ThemeCatalog` 提供一個 helper（如 `_build_default_mesh_library()`）以程式碼造 MeshLibrary，items 即現況的彩色盒子，數值沿用 `world_builder` 現有常數：

| item 名稱 | 幾何 | 顏色（現況） |
|-----------|------|------|
| `floor` | Box 2×0.2×2，頂面 y=0 | `Color(0.25, 0.25, 0.28)` |
| `wall` | Box 2×3×2（footprint 1.0） | `Color(0.5, 0.42, 0.35)` |
| `door` | Box 1.2×2.2×1.2（footprint 0.6） | `Color(0.55, 0.32, 0.15)` |
| `stairs_up` / `stairs_down` | Box 1.6×0.4×1.6（footprint 0.8） | `Color(0.2, 0.5, 0.65)` |

default 主題 `has_ceiling = false`（同現況無天花板）。如此切到 GridMap 後**視覺與現在等價**，只是渲染基底換成 GridMap、且外觀變成可資料驅動置換。

> 註：現況地板是一整塊大 slab；改 GridMap 後是逐格 `floor` tile 拼成，緊貼無縫，視覺等價。

## Godot 場景結構影響

`presentation/world/main.tscn`：`WorldBuilder`（Node3D）維持原節點型別，不需手改 .tscn 結構；其下的 GridMap 由 `world_builder.gd` 在執行時建立/管理。`PlayerController`、`Camera3D`、`DirectionalLight3D` 不動。

## 素材匯入流程（文件，供內容期照做）

於 spec/plan 隨附一份「如何把一個 kit 變成主題」步驟（暫不實際接上特定 kit）：

1. 下載 CC0/CC-BY kit（`.glb`/`.gltf`），放 `content/themes/<theme>/`。
2. Godot 編輯器：把零件組成 MeshLibrary（或用 kit 附場景轉 MeshLibrary），item 命名對齊角色：`floor` / `wall` / `door` / `stairs_up` / `stairs_down` /（可選）`ceiling`。匯入時正規化縮放成「2×2 footprint、牆高 3、pivot 在底面中心」。
3. 建一個 `DungeonTheme.tres`：填 `theme_id`、指 `mesh_library`、填 `item_for_tile`、視需要開 `has_ceiling`。
4. `ThemeCatalog._THEMES` 加一行 `id → .tres`。
5. 在地圖 ASCII header 寫 `theme: <id>`。
6. （CC-BY）在 `CREDITS` / `content/themes/<theme>/ATTRIBUTION.txt` 記來源與授權。

## 測試策略

**可單元測試（引擎/資料層，GUT + TDD）**

- `MapAsciiImporter`：有 `theme:` header → `theme_id` 正確；無 header → `"default"`；未知 `key:` 指令被忽略且不破壞格子解析；header 後格子座標/起點/遭遇仍正確。
- `MapData.theme_id` 預設值為 `"default"`。
- `ThemeCatalog`：`get_theme("default")` 回非空且 `mesh_library` 有 `floor`/`wall`/`door`/`stairs_up`/`stairs_down` items；查無 id → 退回 default；`has_theme` / `all_ids` 行為。

**呈現層（手動/整合，照本專案慣例）**

- GridMap 渲染、外觀正確性：手動跑 `./run.sh` 目視（default 主題應與現況等價）。
- 現有 `tests/presentation/test_world_builder.gd` 需配合改寫：從斷言「產出 N 個 MeshInstance3D child」改為斷言「child GridMap 在對應 cell 有對應 item」（GridMap `get_cell_item` 可在無頭測試查詢，不需渲染）。

## 不變式

- 加一張地圖 / 加一個主題 = 加資料檔（地圖 ASCII、`DungeonTheme.tres`、MeshLibrary、`_THEMES` 一行），**不碰引擎層**。
- 切到 GridMap 後 default 主題外觀與現況等價。
- save schema 不變。

## 本期自主決定（請於 spec review 確認或否決）

1. **主題以 ASCII `theme:` header 宣告**（而非外部 map_id→theme 對照表）：主題與地圖同檔、就近可見，且 importer 改動小、可測。
2. **`default` 主題以程式碼生成**：讓整條 GridMap 管線零外部素材即可驗證並保留現有外觀；實際接 kit 延到內容期，不阻塞本里程碑。
3. **`world_builder` 持有 child GridMap**（而非把 script base class 改成 GridMap）：避免動 main.tscn 節點型別，clear/rebuild 邏輯單純。
4. **`cell_size = (2.0, 3.0, 2.0)`**：X/Z 對齊 `CELL_SIZE=2.0`，Y 對齊 `WALL_HEIGHT=3.0` 以便天花板放上一層。

## 里程碑交付物

- `resources/dungeon_theme.gd`（`DungeonTheme` Resource）
- `MapAsciiImporter` 擴充 header 解析 + `MapData.theme_id` 欄位
- `presentation/world/theme_catalog.gd`（`ThemeCatalog` + 程式碼生成 default MeshLibrary）
- `world_builder.gd` 改寫成驅動 child GridMap
- 對應 GUT 測試（importer / MapData / ThemeCatalog）+ 改寫 `test_world_builder.gd`
- 「如何接 kit」步驟文件（本 spec 內已含，plan 可再具體化）
