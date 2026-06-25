# M7 多地圖世界 + 切換 — 設計

- **日期**：2026-06-25
- **狀態**：設計待核可（spec review gate）
- **範圍**：把單一地圖升級成「多張 `MapData` 互連的世界」。提供兩種地圖間切換——**邊緣無縫接壤**（野外）與**明確入口連結**（城鎮/地牢/區界）——兩者匯流到單一進入路徑 + 一段呈現層轉場。連結全部寫在各地圖 `.txt` 的 header（延續 `theme:` 慣例），每張圖自我描述。不碰戰鬥/法術效果/背包邏輯；存檔 schema 不變。

## 目標

- 世界 = 一張張 grid `MapData`，用兩種方式互連：
  - **邊緣接壤**：走出地圖邊緣 → 接到鄰圖對邊、同側橫向座標、保持面向（野外像 MM3 一張張無縫接壤）。
  - **入口連結**：踩特定標記格 → 切到目標圖的命名入口（pos + facing）。
- 兩種切換都呼叫同一個 `MapManager` 進入路徑 + 同一段呈現層轉場（淡出 → 重建場景 → 放隊伍），重用既有 `_on_loaded` 原語。
- 連結與鄰接全部宣告在各地圖 `.txt` 的 header（延續 `theme:` header 慣例，`MapAsciiImporter` 既有「未知指令忽略」鉤子）。
- 整條管線**零外部素材**即可端對端驗證（用程式碼生成的 `default` 主題 + 一組示範地圖）。
- 存檔 schema **不變**：`current_map_id` / `player_pos` / `player_facing` / `cleared_encounters` 已涵蓋所需；連結屬靜態內容，載入時由 `MapData` 帶出。

## 非目標（本里程碑不做）

- 切換 tile 的精緻外觀（樓梯/城門/傳送點的 3D 視覺）。屬美術/主題軌（與本期分開）。本期入口格 render 為地板，靠到達訊息提示。
- NPC、對話、寶箱、設旗標等通用 tile 事件。屬 M8（事件 + NPC 對話骨幹）。
- 世界地圖總覽 UI、迷你地圖、自動尋路。
- 邊緣接壤的「不同尺寸位移對齊 / 偏移」。本期要求接壤兩圖共邊維度相同（見核心決策）。
- `teleport`（同圖前方穿牆位移）。非多地圖範圍，留待後續（PlayerController.warp_to）。

## 核心決策

| 層面 | 決定 | 理由 |
|------|------|------|
| 世界表示 | 一張張 `MapData`，無獨立 overworld 模式 | 城鎮/地牢/野外都是 grid 地圖，統一模型；貼合既有 `MapData` 架構 |
| 切換種類 | 邊緣接壤 + 入口連結，兩者匯流到單一 `transition_to` | 兩種觸發點不同（移動驗證層 vs 進入格），但下游「重建+放隊伍」一致 |
| Authoring | 各地圖 `.txt` header 自我描述（延續 `theme:`） | 連結與網格同檔、就近可見；importer 改動小、可測；每張圖自我描述 |
| 邊緣對齊 | 共邊維度相同、橫向座標保留、保持面向；對邊實心則擋住 | 最單純、最忠於 MM3 等尺寸野外格；零座標對映歧義 |
| 入口標記 | 網格用大寫 A–Z 標記格（tile = `FLOOR`） | 不撞既有 `# . @ D < > a-z`；可走；多張圖各自 scope |
| 命名入口 | 符號名稱（`entry <name>: x,y [facing]`），非裸座標 | 別圖以符號瞄準、改圖不易斷；`@` 隱含 `start` 入口 |
| 觸發方式 | 兩種切換皆自動（無 Y/N 確認） | 骨幹從簡；確認提示可日後當 per-link 選項加 |
| 存檔 | schema 不變（version 維持 3） | 位置與已清遭遇已存；連結為靜態內容，載入時重新帶出 |

## 架構（三層分離，沿用既有風格）

### ① 資料層 — `MapData` 新欄位

`resources/map_data.gd` 新增（皆 `@export`，屬靜態內容，**不進存檔**）：

| 欄位 | 型別 | 說明 |
|------|------|------|
| `display_name` | `String` | 顯示名（入口切換訊息用），預設空 → 退回 `map_id` |
| `neighbors` | `Dictionary` | `GridDirection.Dir(int) → map_id(String)`，四向邊鄰（缺 = 該向為實心邊界，同現況） |
| `entries` | `Dictionary` | `name(String) → { "pos": Vector2i, "facing": int }`；`@` 隱含一個 `start` 入口 |
| `links` | `Dictionary` | `cell(Vector2i) → { "map": String, "entry": String }` |

- `neighbors` / `entries` / `links` 由 `MapAsciiImporter` 從 header 與網格標記填入。
- 既有 `get_tile` / `has_encounter` 等不變。

### ② 內容/解析 — ASCII header 與標記擴充（`MapAsciiImporter`）

沿用既有指令偵測（`^[a-z_]+:` 視為指令、格子行永遠不含 `:`、未知指令忽略）。新增認得的指令：

```
theme: wild_grass
name:  翠原東野
north: wild_north        # 邊緣鄰圖（key ∈ {north,east,south,west}）
east:  wild_east
entry gate: 4,9 S        # 命名到達點：x,y[ +可選面向 N/E/S/W]
link T: town_oak.gate    # 網格標記 'T' → 切到 town_oak 的 'gate' 入口
########
#..T...#
#..@...#
########
```

解析規則：
- `name:` → `display_name`。
- `north:/east:/south:/west:` → `neighbors[GridDirection.Dir.X] = value`。
- `entry <name>: x,y[ facing]` → `entries[name] = {pos, facing}`；facing 省略 → `NORTH`。
- `link <MARKER>: <dest_map>.<entry_name>` → 記錄「標記字母 → {map, entry}」對照；解析網格時，遇到該大寫標記字母的格：tile 設為 `FLOOR`、於 `links[cell]` 記下目的地。
- **網格大寫標記字母**：`_char_to_tile` 擴充——大寫 A–Z 且該字母在本圖有對應 `link` 宣告 → 視為 `FLOOR` 並登記 link；無對應宣告的大寫字母 → 維持「未知字元 → null」（嚴格，避免打錯字默默吃掉）。
- `@` 起點：除設 `start_pos` 外，於 `entries["start"] = {pos: start_pos, facing: start_facing}`，讓別圖能以 `<map>.start` 或預設瞄準。

> 合法格子字元仍不含 `:`，指令偵測無歧義。舊地圖（無新 header）行為不變。

### ③ 引擎層 — 純切換邏輯（可單元測試，TDD）

新增 `engine/map/map_transitions.gd`（`class_name MapTransitions extends Object`），全部 static、純資料、不依賴視覺節點：

- `direction_of(facing: int, move: int) -> int`：把 `GridMovement.Move` 換成世界方向（從 `GridMovement.resolve` 抽出的邏輯）。
- `edge_exit(map: MapData, pos: Vector2i, move_dir: int) -> Dictionary`：
  - `target = pos + GridDirection.to_vector(move_dir)`；若 `target` 仍在界內 → `{}`（非邊緣事件）。
  - 出界且 `map.neighbors` 有 `move_dir` → `{ "neighbor_id", "edge_dir": move_dir, "lateral": <橫向座標> }`；否則 `{}`。
- `arrival_cell(dest_map: MapData, edge_dir: int, lateral: int) -> Vector2i`：算「自 `edge_dir` 進入 `dest_map` 的對邊、同側 `lateral` 格」；若該格實心或 lateral 出界 → `Vector2i(-1, -1)`（擋住、不切換）。
- `resolve_link(map: MapData, pos: Vector2i) -> Dictionary`：`map.links.has(pos)` → 回 `{map, entry}`，否則 `{}`。

`GridMovement`：`resolve` 維持不變；新增 `direction_of(facing, move) -> int`（或委派給 `MapTransitions.direction_of`），供 `PlayerController` 知道「被擋方向」。

### ④ 切換協調 — `MapManager` + 呈現層

**`MapManager.enter_map(map_id: String, cleared_positions: Array) -> MapData`**：抽出「`load_by_id` + 逐格 `clear_encounter` 重套已清遭遇」的共用邏輯。`SaveSystem.apply_to` 改呼叫它（DRY；現況該段邏輯內聯在 `apply_to`）。`transition_to` 也走它，確保重入地圖時已清的怪不復活。

**`PlayerController`**：新增 `signal edge_exit_attempted(move_dir: int)`。`_attempt_move` 改為：先以 `direction_of` 取得世界方向算出 `target`；
- 界內且可走 → 同現況補間移動。
- 界內但實心 → 撞牆，不動（同現況）。
- 出界 → 發 `edge_exit_attempted(move_dir)` 並 return（不補間；由 `main` 決定是否切換）。

**`main.gd`**：
- 新增 `_transition(map_id, entry_name_or_cell, facing)`：淡出黑幕 → `MapManager.enter_map(map_id, GameState.cleared_for(map_id))` → `_world_builder.build(MapManager.current_map)` → 解析抵達 pos/facing → `_player.setup(MapManager.current_grid, pos, facing)` → 更新 `GameState.current_map_id/player_pos/player_facing` → 淡入。
- 掛 `_player.edge_exit_attempted`：用 `MapTransitions.edge_exit` 取鄰圖，`enter_map` 後 `arrival_cell` 算抵達格；若回 `(-1,-1)`（對邊實心）→ 不切換（視為撞牆）。
- `_on_entered_cell` 開頭加 link 檢查（`MapTransitions.resolve_link`）：命中 → 切換並 `return`（**先於遭遇檢查**；同格不應同時是 link 與 encounter，作者勿重疊）。
- 黑幕：一個 `ColorRect`（`CanvasLayer`）+ tween 淡出入，遮住 1-frame 重建；邊緣與入口切換共用。
- 起始地圖：以 `GameState.current_map_id`（未設則預設常數 `START_MAP_ID`）載入，取代寫死的 `MAP_PATH`。

### ⑤ 順帶接線：`town_portal`（recall 法術）

`main.gd._cast_recall` 目前是 stub（註解明寫「城市傳送目的地待多地圖基建後實作」）。M7 把它接到 `_transition(HOME_MAP_ID, "start", facing)`，讓城市傳送機制可動（實際「家城」屬內容期內容，本期以示範城鎮充當）。`teleport`（同圖穿牆位移）非多地圖範圍，stub 留待後續。

## Godot 場景結構影響

`presentation/world/main.tscn`：`WorldBuilder` / `PlayerController` / `Camera3D` / 燈光 / `WorldEnvironment` 節點型別與結構**不變**。黑幕 `CanvasLayer` 由 `main.gd` 在執行時建立。切換時 `world_builder.build()` 重建 child GridMap（M6 既有行為），`PlayerController.setup()` 重新定位。

## 測試策略

**可單元測試（引擎/資料層，GUT + TDD）**

- `MapAsciiImporter`：
  - `name/north/east/south/west/entry/link` 解析正確；`entries["start"]` 由 `@` 帶出。
  - 大寫標記格：有對應 `link` → tile 為 `FLOOR` 且 `links[cell]` 正確；無對應宣告的大寫字母 → `parse` 回 `null`（嚴格）。
  - 未知 `key:` 指令仍忽略、不破壞格子解析；header 後格子座標/起點/遭遇仍正確。
  - 舊地圖（無新 header）→ 欄位為空預設，行為不變。
- `MapTransitions`：`direction_of`；`edge_exit`（界內回空、出界有鄰圖回事件、出界無鄰圖回空）；`arrival_cell`（對邊同側、對邊實心回 `(-1,-1)`、lateral 出界回 `(-1,-1)`）；`resolve_link`。
- `MapData`：新欄位預設值（`neighbors/entries/links` 空、`display_name` 空）。
- `MapManager.enter_map`：載入後重套 `cleared_positions`（對應格 `has_encounter` 為 false）。
- `SaveSystem.apply_to` 改用 `enter_map` 後行為等價（既有存讀檔測試應仍綠）。

**呈現層（手動/整合，照本專案慣例）**

- 跑 `./run.sh` 目視：走出邊緣接到鄰圖（保持面向、同側位置）；踩入口標記格進城並出現到達訊息；轉場黑幕；城鎮出口走回野外正確 `entry`；存檔後讀回到非起始地圖位置正確；`town_portal` 傳送到示範城鎮。

## 不變式

- 加一張地圖 / 連一條路 = 加/改地圖 `.txt`（header 指令 + 網格標記），**不碰引擎層**。
- 兩種切換共用同一條「進入地圖」路徑（`MapManager.enter_map`）；切換與讀檔重入地圖皆重套已清遭遇。
- 存檔 schema 不變（version 3）。
- 舊地圖（無新 header）行為與現況等價。

## 本期自主決定（請於 spec review 確認或否決）

1. **邊緣接壤要求共邊維度相同**、橫向座標保留、保持面向；對邊格實心則擋住（不切換）。
2. **兩種切換皆自動觸發**（無 Y/N 確認）；確認提示留作日後 per-link 選項。
3. **入口標記用大寫 A–Z**；標記格 tile = `FLOOR`，視覺外觀延後到主題軌。無對應 `link` 宣告的大寫字母 → 解析失敗（嚴格，抓打字錯）。
4. **切換 tile 無專屬 3D 外觀**（render 為地板 + 到達訊息）。
5. **`town_portal`（recall）在 M7 接線**到示範城鎮；`teleport` 留待後續。
6. **附一組示範地圖**（野外 2×2 接壤 + 一座城鎮，純驗證端對端），屬本里程碑交付。

## 里程碑交付物

- `resources/map_data.gd`：`display_name` / `neighbors` / `entries` / `links` 四新欄位。
- `engine/map/map_ascii_importer.gd`：header（`name/north/east/south/west/entry/link`）+ 大寫標記解析。
- `engine/map/map_transitions.gd`：`direction_of` / `edge_exit` / `arrival_cell` / `resolve_link`。
- `engine/grid/grid_movement.gd`：`direction_of`（供 PlayerController 取被擋方向）。
- `autoload/map_manager.gd`：`enter_map(map_id, cleared_positions)`。
- `autoload/save_system.gd`：`apply_to` 改用 `enter_map`。
- `presentation/world/player_controller.gd`：`edge_exit_attempted` 訊號 + `_attempt_move` 出界分支。
- `presentation/world/main.gd`：`_transition` + 黑幕 + 邊緣/入口掛接 + 起始圖來源 + `town_portal` 接線。
- 對應 GUT 測試（importer / MapTransitions / MapData / MapManager.enter_map）。
- 一組示範地圖（野外 4 張接壤成 2×2 + 1 座城鎮）驗證端對端。
