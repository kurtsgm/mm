# M8b-3 互動寶箱 — 設計

- **日期**：2026-06-26
- **狀態**：設計已核可，待產出實作計畫
- **範圍**：在地圖上放可開的寶箱——踩上寶箱格自動跳 Y/N 確認，開箱發放 gold + 道具、一次性持久化。同格怪物優先（先戰鬥，勝利後自動補跳開箱）。寶箱開/關兩態視覺。這是 M8b 物件層的第三個增量，重用 M8b-1 的「每區一物件層」拼裝渲染路徑。

## 目標

- 在 `MapData` 加一個通用「互動物件」陣列 `objects`，以 `chest` 型別落地寶箱；之後拉桿/NPC/機關可共用同一條解析與渲染通道。
- 玩家踩上寶箱格 → 自動 Y/N 確認 → 開箱發放 gold + 道具。
- 寶箱一次性：開過就持久化（存讀檔後仍是開的、不能重拿）。
- 同格怪物優先：寶箱格上若有未清遭遇，先戰鬥；勝利後自動補跳開箱（「看守怪→開寶箱」無縫）。
- 寶箱開/關兩態視覺（未開=關蓋、已開=開蓋）。

## 不做（YAGNI，明確排除）

- 陷阱寶箱、上鎖/鑰匙、稀有度/亂數內容（本期寶箱內容固定寫在地圖 JSON）。
- NPC、拉桿、機關等其他互動物件（`objects` 陣列為未來預留，本期只實作 `chest` 型別）。
- 存檔 schema 升版（save 已是 **v4**，本期只「追加」`opened_objects` 欄位，不升版號）。
- 新增互動輸入鍵（沿用 `entered_cell` 進格觸發，不加 E/Space 之類的互動鍵）。
- 寶箱碰撞（寶箱在可走地板格，踩上去即觸發；不擋路）。

## 設計決策

| 面向 | 決定 | 理由 |
|------|------|------|
| 互動方式 | 踩上寶箱格 → 自動跳 Y/N | 重用現有 `PlayerController.entered_cell` → `main._on_entered_cell` 觸發鏈，零新輸入動作 |
| 觸發優先序 | link → encounter（未清）→ chest（未開）→ tile message | 同格怪物優先；寶箱插在遭遇之後、地板訊息之前 |
| 戰後流程 | 勝利清怪後，若該格有未開寶箱 → 自動補跳開箱 | 實現「看守怪→開寶箱」無縫；不需玩家重踩 |
| 寶箱內容 | 固定寫在地圖 JSON（`items` 陣列 + `gold` 整數） | 最省；亂數/掉落表留待內容期，本期 YAGNI |
| 持久化 | `GameState.opened_objects`（map_id → Array[Vector2i]），完全鏡射 `cleared_encounters` | 已驗證的 per-map 座標集合模式，serializer 可照抄 `_cleared_*` |
| 存檔版本 | 維持 v4，只「追加」欄位 | 舊檔無此欄 → `.get(...,{})` 視為空，向後相容；同 theme_id「靜態不序列化、動態才序列化」原則 |
| 兩態視覺渲染 | 寶箱走和裝飾相同的「每區一層」拼裝路徑（`WorldStitchRenderer` 加第三子層 `ChestLayer`），用 `GameState.opened_for(map_id)` 餵開啟狀態 | 鄰圖寶箱也可見、跨界無 pop-in；與裝飾一致 |
| 開箱中途更新 | renderer 加 `refresh_objects(map)`，只重建「目前區」的 `ChestLayer` | 便宜（只重建一張圖的物件層），不動 M10 pooling 的跨界重定位不變式 |
| 狀態層隔離 | 新增獨立 `ChestLayer`（狀態感知），不改 `ObjectLayer`（純裝飾、無狀態） | 單一職責；裝飾渲染保持無狀態、既有測試不受影響 |
| 開箱邏輯 | 純函式 `ChestLoot.grant(chest, inventory)`（引擎層），不碰 autoload | 三層分離；可不靠節點/autoload 做單元測試 |

### 替代方案與取捨

- **渲染**：替代是「只渲染目前圖的專屬 `ChestLayer`」（更簡單、中途更新更直接），但跨界時鄰圖寶箱會 pop-in。既然本期要兩態視覺品質，採無縫拼裝 + `refresh_objects`。
- **互動**：替代是「面對寶箱按互動鍵」（更刻意、更傳統 RPG），但要新增輸入 action + 朝向目標偵測。採「踩上自動跳」以重用既有觸發鏈、零新輸入。

## 實作單元

### 1. 資料模型（`resources/map_data.gd`）
- 新 `@export var objects: Array = []`；每元素 `{ "pos": Vector2i, "items": Array[String], "gold": int, "model": String }`。
- 查詢輔助：`has_object(pos) -> bool`、`get_object(pos) -> Dictionary`（沿用 links/encounters 的查詢風格）。

### 2. 匯入（`engine/map/map_importer.gd`）
- `_parse_entities` 的 `match` 加 `"chest"` 分支：
  - `items`（可選）：須為陣列，元素轉 String；省略 → 空陣列。
  - `gold`（可選）：須為數字且 ≥0（`_is_num` + 轉 int）；省略 → 0；負數或非數字 → null（拒絕整張地圖，沿用嚴格解析）。
  - `model`（可選）：String，預設 `"chest"`。
  - pos 越界沿用現有檢查 → null。
- 回傳新增 `objects` 陣列；`parse()` 寫入 `map.objects`。

### 3. 狀態（`autoload/game_state.gd`）
- 新 `var opened_objects: Dictionary = {}  # map_id -> Array[Vector2i]`。
- `mark_object_opened(map_id, pos)`、`is_object_opened(map_id, pos) -> bool`、`opened_for(map_id) -> Array`（鏡射 `mark_encounter_cleared/cleared_for`）。

### 4. 存檔（`engine/save/save_data.gd` + `save_serializer.gd` + `autoload/save_system.gd`）
- `SaveData` 加 `var opened_objects: Dictionary = {}`。
- `SaveSerializer`：
  - `VERSION` 維持 **4**。
  - `to_dict` 的 `state` 加 `"opened_objects": _opened_to_dict(data.opened_objects)`。
  - `from_dict` 加 `data.opened_objects = _opened_from_dict(s.get("opened_objects", {}))`。
  - 新 `_opened_to_dict / _opened_from_dict`（複製 `_cleared_to_dict / _cleared_from_dict`，內層為 `Array[Vector2i]`）。
- `SaveSystem.capture_from / apply_to` 各加一行帶上 `opened_objects`。

### 5. 開箱邏輯（`engine/world/chest_loot.gd`，新）
- `class_name ChestLoot extends Object`。
- `static func grant(chest: Dictionary, inventory: Inventory) -> Dictionary`：
  - 對 `chest["items"]` 每個 id `inventory.add(id, 1)`。
  - 回 `{ "gold": int(chest.get("gold", 0)), "items": <加入的 item id 陣列> }`。
- 不碰 `GameState`／不發訊息；金幣加總與訊息由 `main` 端負責（保持純邏輯可測）。

### 6. 寶箱目錄（`presentation/world/chest_catalog.gd`，新）
- `class_name ChestCatalog extends Object`，`const _STYLES := { "chest": { "closed": "res://content/models/chest/chest_closed.tscn", "open": "res://content/models/chest/chest_open.tscn" } }`。
- `has_style(id) -> bool`、`get_scene(id, opened: bool) -> PackedScene`（依 opened 取 closed/open，未知 id → null）。
- 實際檔名待素材下載後定（同 grass/castle_wall 的「檔名到位再填」流程，非設計缺口）。

### 7. 寶箱渲染層（`presentation/world/chest_layer.gd`，新）
- `class_name ChestLayer extends Node3D`。
- `build(map: MapData, opened: Dictionary, catalog = null) -> void`：清空子節點；對每個 `map.objects`（本期皆 chest）取 `catalog.get_scene(model, opened.has(pos))`，`instantiate()`，`position = GridGeometry.cell_to_world(pos)`，`add_child`。`opened` 為 `{Vector2i -> true}` 風格集合（可由 `GameState.opened_for` 轉入，或測試注入）；`catalog` 可注入（預設 `ChestCatalog`）。

### 8. 拼裝渲染接線（`presentation/world/world_stitch_renderer.gd`）
- `_build_content` 在 `WorldBuilder` + `ObjectLayer` 之後再加一個 `ChestLayer` 子節點，用 `_opened_set(map.map_id)` build。
- 新 `refresh_objects(map: MapData) -> void`：找 `_regions[map.map_id]` 容器中的 `ChestLayer` 子節點，以最新 `opened` 重建（只重建這一張圖的寶箱層，不動其他區、不動地形）。
- `_opened_set(map_id)`：把 `GameState.opened_for(map_id)`（Array[Vector2i]）轉成 `{pos -> true}`。為保持測試 seam，沿用既有 `region_builder` 注入（測試走假 builder 時不碰 GameState）。

### 9. Y/N 確認 UI（`presentation/ui/chest_prompt.gd`，新）
- `class_name ChestPrompt extends CanvasLayer`，鏡射既有選單介面：`open()`、`close()`、`is_open() -> bool`，訊號 `confirmed`、`declined`。
- 畫面：置中 Label「打開寶箱？(Y/N)」。
- 輸入：`_unhandled_input` 處理 `KEY_Y` → `confirmed`、`KEY_N` → `declined`（開啟時才吃；關閉即放行）。

### 10. 接線（`presentation/world/main.gd`）
- `_ready`：建立 `_chest_prompt = ChestPrompt.new()` 加為子節點，連 `confirmed`/`declined`。
- `_on_entered_cell` 觸發鏈插入寶箱檢查（在 encounter 之後、tile message 之前）：
  - `if MapManager.current_map.has_object(pos) and not GameState.is_object_opened(map_id, pos): _prompt_chest(pos); return`。
- `_prompt_chest(pos)`：記 `_chest_pos = pos`；`_player.set_enabled(false)`；`_chest_prompt.open()`。
- `confirmed`：`var chest = current_map.get_object(_chest_pos)`；`var res = ChestLoot.grant(chest, GameState.inventory)`；`GameState.gold += res.gold`；`GameState.mark_object_opened(map_id, _chest_pos)`；`_world_renderer.refresh_objects(current_map)`（換開蓋）；push 訊息（「獲得 N 金幣」「獲得道具：X」）；`_chest_prompt.close()`；`_player.set_enabled(true)`；`_hud.refresh()`。
- `declined`：`_chest_prompt.close()`；`_player.set_enabled(true)`。
- `_on_combat_finished` 勝利分支：清怪後改為——若該格有未開寶箱 → `_prompt_chest(_combat_pos)`（由 prompt 流程關閉時再放行）；**否則** `set_enabled(true)`（維持現行行為）。FLED/DEFEAT 分支不變。

### 11. 內容
- `content/models/chest/chest_closed.tscn` + `chest_open.tscn`（+ 來源 GLB 與 Godot import 檔）。素材由使用者下載 CC0 kit（同前幾期流程）。
- `content/maps/town_oak.json`（5×5、內部 3×3 可走，start @ (2,2)、portal (2,3)）的 `entities` 加：
  - 普通寶箱：`{ "type":"chest", "pos":[1,1], "items":["potion"], "gold":50 }`。
  - 看守寶箱（同格怪物優先 demo）：在 (3,1) 同格放一個 `chest` 與一個 `monster` entity（`pos` 皆 [3,1]，monster 的 `encounter` 用既有遭遇 id，見 `Bestiary`）。`encounters[pos]` 與 `objects` 存於不同結構，同格不衝突。

## 測試（TDD，沿用 GUT）

- `tests/engine/map/test_map_importer.gd`：
  - `chest` entity → `map.objects` 含 `{pos, items, gold, model}`；
  - `items`/`gold`/`model` 省略 → 預設（空陣列/0/"chest"）；
  - `gold` 負數或非數字 → `parse` 回 null；越界 pos → null。
- `tests/autoload/test_game_state.gd`（或新 `test_game_state_objects.gd`）：`mark_object_opened` / `is_object_opened` / `opened_for` 行為。
- `tests/engine/save/test_save_serializer.gd`：`opened_objects` round-trip；舊檔（無此欄）→ 空集合、不報錯（向後相容）。
- `tests/autoload/test_save_system_capture_apply.gd`：capture/apply 帶上 `opened_objects`。
- `tests/engine/world/test_chest_loot.gd`（新）：`grant` 把 items 加進注入的 `Inventory`、回傳正確 gold 與 item id 陣列；空寶箱 → gold 0、items 空。
- `tests/presentation/test_chest_catalog.gd`（新）：註冊 style `has_style`；`get_scene(id, opened)` 取對應 closed/open 非 null；未知 id → null。
- `tests/presentation/test_chest_layer.gd`（新）：注入假 catalog + `opened` 集合，`build(map, opened)` 後子節點數 == objects 數、各節點 `position == cell_to_world(pos)`、opened 格取 open 場景、未開取 closed。
- `tests/presentation/test_world_stitch_renderer.gd`：`refresh_objects` 只重建目標區 ChestLayer（用 `region_builder` seam 驗證不誤觸其他區）。
- 既有 333 測試不受影響（`objects` 預設空；monster/portal/decoration 解析不變）。

## 驗收

- `./run.sh`：
  - 從野外城門進 `town_oak` → 走到普通寶箱格 → 跳「打開寶箱？(Y/N)」→ 按 Y → 訊息顯示獲得金幣與道具、寶箱模型變開蓋。
  - 對開過的寶箱再踩 → 不再跳 prompt（已開、不能重拿）。
  - 走到看守寶箱格 → 先遭遇戰鬥 → 勝利後自動跳開箱 prompt。
  - 存檔 → 重讀：已開寶箱仍是開蓋、踩上去不跳 prompt；金幣/道具保留。
- 測試套件全綠（新增 importer/state/save/loot/catalog/layer/renderer 斷言）。

## 後續增量（本 spec 之後）

- **M8b-2**：內部城鎮——`town_oak` 改成有低多邊形建築、可走街道（建築 footprint=WALL 擋路、商店=門格），用同一裝飾層擺建築。
- 互動物件擴充：用同一 `objects` 陣列加拉桿/開關、NPC 對話（重用 `is_object_opened`/prompt 通道）。
