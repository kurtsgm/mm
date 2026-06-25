# M8a 地圖格式 JSON 化（物件層前置重構）— 設計

- **日期**：2026-06-25
- **狀態**：設計待核可（spec review gate）
- **範圍**：把地圖來源格式從「header 指令 + 純 ASCII 網格的 `.txt`」換成「**JSON 容器**：`grid` 用 ASCII 列字串陣列（保留一眼可讀）＋結構化 `entities` / `entries` / `neighbors`」。這是「**通用地圖物件層（寶箱／可疊怪）**」這條線的**步驟一：純格式遷移**。`MapImporter` 改吃 JSON、產出**語義完全相同的 `MapData`**；runtime、`MapData` 欄位、存檔 schema 皆不變。物件層本身（`chest`、重疊、存檔 v4、確認 UI）屬**步驟二（M8b）**，本 spec 不做。

## 為什麼先做這一步

- 後續地圖物件「**型別會多、每型別資料會變巢狀**」（怪物類別 + 物件類別，且各帶不同欄位）。現行「一格一字元 + header 單行冒號語法」會撐不住（`chest x,y: a b gold:50` 一旦要加陷阱／上鎖／條件／對話／數量就變醜）。
- 重疊（怪物與物件同格）本來就不是格式能不能表達的問題（座標宣告即可），但要做得乾淨、可無限擴充，結構化格式才是對的地基。
- 先把**格式**換成結構化、可測、行為不變的版本，再在乾淨地基上**只加法**地長出物件層（步驟二）。每步小、可測、好回退，延續本專案一路風格。

## 非目標（本步驟不做）

- 不新增 `chest`、不做「怪物優先後同格物件生效」的重疊行為、不動存檔 schema（維持 v3）、不做 Y/N 確認 UI。**以上全屬步驟二（M8b）**。
- 不做 JSON→`.tres` 預編譯（bake）。屬未來選配；因 `MapData` 已是 `Resource`、`MapImporter` 為純函式，屆時加一層 `ResourceSaver.save` 即 drop-in，現在不做不浪費。
- `MapData` **不新增任何欄位**。`entities` 僅為「輸入表示」，由 importer 分配進既有的 `encounters` / `links` / `entries` / `neighbors`。

## 核心決策

| 層面 | 決定 | 理由 |
|------|------|------|
| 容器格式 | JSON（Godot 原生 `JSON.parse_string`，零依賴） | 結構化、可無限擴充型別/巢狀欄位；YAML 在 Godot 無第一方解析器，不採用 |
| 網格可讀性 | `grid` 存成 ASCII 列字串陣列（`["#####","#.@.#",...]`） | 地圖形狀仍一眼可讀、好手改、diff 乾淨；沿用現有字元集與 tile 對映 |
| 怪物/連結表示 | 移出格子，改為 `entities` 陣列（`type` + `pos` + 欄位） | 消除「怪物是字元、其他是 header」的不對稱；為步驟二統一物件層鋪路；同 `pos` 兩 entity = 天生可重疊 |
| MapData 形狀 | **不變**（仍 `tiles/encounters/links/entries/neighbors/...`） | 步驟一是純 I/O 格式遷移；下游 runtime/存檔/測試斷言不動 |
| importer 命名 | `MapAsciiImporter` → `MapImporter` | 容器已是 JSON，名稱要誠實；格子核心（`_char_to_tile`）保留重用 |
| 驗證 | 沿用「任何違規 → 回 `null`」 | 與現行 importer 契約一致；嚴格抓壞地圖 |
| 副檔名 | 地圖檔 `.txt` → `.json`，刪舊 `.txt` | 一種格式、一條載入路徑 |

## JSON Schema（步驟一）

```json
{
  "name": "範例圖（僅示意全欄位）",
  "theme": "default",
  "grid": [
    ".....",
    ".....",
    "..@..",
    ".....",
    "....."
  ],
  "entities": [
    { "type": "monster", "pos": [2, 1], "encounter": "g" },
    { "type": "portal",  "pos": [3, 3], "to": "town_oak", "entry": "gate" }
  ],
  "entries":   { "from_town": { "pos": [2, 3], "facing": "N" } },
  "neighbors": { "east": "wild_ne", "south": "wild_sw" }
}
```

> `pos` 一律 `[x, y]`＝`[欄, 列]`，對應 `Vector2i(x, y)` 與 `tiles[y * width + x]`（`grid` 第 `y` 列字串的第 `x` 個字元）。

| 欄位 | 必填 | 型別 | 對映到 `MapData` |
|------|------|------|------------------|
| `grid` | ✅ | `Array[String]`（矩形、字元 ∈ `# . @ D < >`） | `tiles` + `start_pos`（`@`） |
| `theme` | — | `String`（預設 `"default"`） | `theme_id` |
| `name` | — | `String` | `display_name`（空 → 退回 `map_id`） |
| `entities` | — | `Array[Object]`（見下） | 分配進 `encounters` / `links` |
| `entries` | — | `{ name: { pos:[x,y], facing?:"N/E/S/W" } }` | `entries[name]`（`facing` 省略 → `NORTH`） |
| `neighbors` | — | `{ north/east/south/west: map_id }` | `neighbors[GridDirection.Dir]` |

**entity 型別（步驟一只認兩種）**

| `type` | 欄位 | 對映 |
|--------|------|------|
| `monster` | `pos:[x,y]`, `encounter:String` | `encounters[Vector2i(pos)] = encounter` |
| `portal` | `pos:[x,y]`, `to:String`, `entry?:String` | `links[Vector2i(pos)] = { "map": to, "entry": entry或"start" }` |

**對映規則補充**
- `grid`：字元集與 tile 對映**完全沿用**現行 `_char_to_tile`（`#`→WALL、`.`→FLOOR、`@`→FLOOR 且記 `start_pos`、`D`→DOOR、`<`→STAIRS_UP、`>`→STAIRS_DOWN）。
- `@`：仍隱含 `entries["start"] = { pos: start_pos, facing: NORTH }`（同現行 importer 行為），別圖可以 `<map>.start` 瞄準。
- 其餘實體（怪物、portal）一律走 `entities`，**不再用格子字元**（`a-z` 怪物標記、`A-Z` 連結標記在 JSON 格式中取消）。

## 驗證（沿用「違規 → null」）

`MapImporter.parse(json_text) -> MapData` 在以下任一情況回 `null`：
- JSON 解析失敗；或頂層不是 Object。
- 缺 `grid`、`grid` 空、或非 `Array[String]`、或**非矩形**、或含未知格子字元。
- 缺 `@` 起點，或有**多個** `@`。
- 任一 entity 缺 `type` / `pos`、`pos` 非 `[int,int]`、或 `pos` 出界。
- entity `type` 不是 `monster` / `portal`（**未知型別嚴格擋下**；步驟二再放行 `chest`）。
- `monster` 缺 `encounter`；`portal` 缺 `to`。

容忍（沿用現況）：`facing` 字串無法辨識 → 退回 `NORTH`。

## importer 重構

- `class_name MapAsciiImporter` → **`MapImporter`**（同步更新所有參照與測試檔名）。
- 公開入口：`MapImporter.parse(json_text: String) -> MapData`。
- 內部把「grid 列字串 → tiles + start_pos」抽成可重用 helper（`_parse_grid(rows) -> Dictionary`），entity 分配各自 helper（`_apply_monster` / `_apply_portal`），維持純函式、無副作用、可單測。
- 保留並重用 `_char_to_tile` / `_facing_word_to_dir` / `_word_to_dir`（方向字串）。移除 header 指令掃描（`_is_directive` 等）與 `a-z`/`A-Z` 格子標記分支。

## `MapManager` 變更

- `load_by_id`：路徑由 `"%s/%s.txt"` → `"%s/%s.json"`。
- `load_text(json)` / `load_text_file(path)`：改吃 JSON（內容已是 JSON 字串）；`map_id` 仍由檔名 basename 帶出（`"wild_nw.json"` → `"wild_nw"`，`get_basename()` 已處理）。
- `enter_map` / `_set_current` 邏輯不變。

## 內容轉檔

五張地圖 `.txt` → `.json`（刪舊檔）：`level01`、`town_oak`、`wild_nw`、`wild_ne`、`wild_se`、`wild_sw`。

範例：`wild_nw.txt`（現行）

```
theme: default
name: 西北野
east: wild_ne
south: wild_sw
entry from_town: 2,3 N
link T: town_oak.gate
.....
.....
..@..
...T.
.....
```

→ `wild_nw.json`（轉檔後，產出的 `MapData` 與現行**逐欄相同**）

```json
{
  "name": "西北野",
  "theme": "default",
  "grid": [".....", ".....", "..@..", ".....", "....."],
  "entities": [
    { "type": "portal", "pos": [3, 3], "to": "town_oak", "entry": "gate" }
  ],
  "entries":   { "from_town": { "pos": [2, 3], "facing": "N" } },
  "neighbors": { "east": "wild_ne", "south": "wild_sw" }
}
```

（`level01` 的 `g`/`o` 怪物 → 兩筆 `monster` entity；`town_oak` 的 `link W` → 一筆 `portal` entity。）

## 測試策略

**改吃新格式（輸入換 JSON、斷言不變）**
- `tests/engine/map/test_map_ascii_importer.gd` → 更名 `test_map_importer.gd`：所有 `MapAsciiImporter.parse("ascii…")` 改為餵 JSON 字串；輸出斷言（tiles/start/encounter/null 情境）維持等價。新增：各 entity 對映、`grid` 列字串往返、未知 entity type → null、缺必填欄位 → null。
- `tests/autoload/test_map_manager.gd`：`test_load_text_sets_current_map_and_grid` 那條的 `load_text("###\n#@#\n###")` 改餵等價 JSON。其餘（`load_by_id` / `enter_map`）靠轉檔後的 `.json` 維持綠。

**維持不變、應持續綠燈（轉檔需忠實，故斷言不動）**
- `tests/content/test_world_maps.gd`：`neighbors` 對稱、共邊維度、`town_link_roundtrip`（`get_link` / `get_entry`）——皆為**輸出**斷言，轉檔忠實即綠。
- `tests/engine/map/test_map_transitions.gd`、`test_map_builder.gd`、`test_tile_messages.gd`。
- 全部 `save` / `combat` / `inventory` / `spell` / `party` / `grid` 測試（不碰格式）。

**驗收**：全測試套件轉檔後維持綠（目前 247/247 概念數，更名與輸入遷移後數量可微調，但**通過率 100%**）。

## 不變式

- runtime 行為 / `MapData` 語義 / 存檔 schema（v3）**不變**。
- 加地圖、連線 = 改 `.json`，不碰引擎層（同 M7 精神，載體換成 JSON）。
- 步驟二（M8b）可在此地基**只加法**地引入：`entities` → `MapData.objects` 通用層、`chest` 型別、怪物優先重疊、`opened_objects` 存檔 v4、Y/N 確認 UI。本步驟刻意不預先埋這些。

## 里程碑交付物

- `engine/map/map_importer.gd`（由 `map_ascii_importer.gd` 重構更名）：`parse(json_text) -> MapData`，JSON + `grid` 列字串解析、entity 分配、嚴格驗證。
- `autoload/map_manager.gd`：`.txt` → `.json` 路徑與 `load_text` 改吃 JSON。
- `content/maps/*.json`：6 張地圖轉檔（刪 `*.txt`）。
- `tests/engine/map/test_map_importer.gd`（更名自 `test_map_ascii_importer.gd`）＋ `tests/autoload/test_map_manager.gd` 輸入遷移；其餘測試保持綠。

## 自主決定（請於 spec review 確認或否決）

1. **importer 更名 `MapImporter`**；測試檔同步更名 `test_map_importer.gd`。
2. **副檔名改 `.json`**，刪除舊 `.txt`。
3. **步驟一 `entities` 僅 `monster` / `portal` 兩型**；`MapData` 不加欄位（`entities` 只是輸入表示）。
4. **嚴格驗證沿用「違規 → null」**；未知 entity `type` → `null`。
5. **`@` 維持在 `grid`**（設 `start_pos` + `entries["start"]`）；其餘實體一律走 `entities`，取消 `a-z`/`A-Z` 格子標記。
6. **不做 `.tres` bake、不做物件層**（皆步驟二）。

## 步驟二預告（非本 spec 範圍，僅記錄已議定方向，屆時另開 brainstorm + spec）

- `entities` → `MapData.objects` 通用物件層；新增 `chest`（道具 id 串 + 可選 `gold`）型別。
- **怪物優先重疊**：踩格先打，戰勝後同格物件才生效。
- **Y/N 確認**：「進入〈城鎮名〉嗎？」「開啟寶箱嗎？」；野外邊緣接壤維持無縫不確認。
- **存檔 v3 → v4**：新增 `opened_objects`（比照 `cleared_encounters`），舊檔可讀（缺欄位 → 空）。
