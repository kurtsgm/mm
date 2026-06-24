# M5a「存檔系統」設計

- **日期**：2026-06-25
- **狀態**：設計已核可，待產出實作計畫
- **里程碑**：M5 拆解後的第一塊。M5「道具/法術/存檔」原本綑綁三個獨立子系統，拆為 M5a（存檔）、M5b（道具/裝備）、M5c（法術），本案先做 **M5a 存檔系統**。
- **前置**：M1–M4 已完成並併入 `main`（格子移動、資料驅動地圖、隊伍/狀態 HUD、遭遇與回合制戰鬥）。

## 目標

把遊戲進度序列化到磁碟並能讀回，支援多存檔槽，並提供存讀檔選單 UI。讀檔後需還原：

- 隊伍（每名角色完整屬性、HP/SP、狀態、經驗）
- 金錢
- 當前地圖 + 玩家座標與面向
- 已擊敗的遭遇（讀檔後不會復活已清的怪）

序列化格式由架構文件既定，本案沿用、不再重議：**JSON、存於 `user://`、多存檔槽、內容以 id 參照**（地圖等大型靜態內容不入存檔）。

## 關鍵決策：玩家座標的單一真實來源

現況：玩家 `pos`／`facing` 私有於 `PlayerController`（呈現層），地圖從寫死路徑載入且 `MapData.map_id` 為空。引擎層（存檔）不應反向讀取呈現層。

- **採用**：把座標提升進 `GameState`，新增 `current_map_id`、`player_pos`、`player_facing`。`main.gd` 已訂閱 `entered_cell` / `facing_changed`，於移動時寫回 `GameState`。`GameState` 成為「隊伍在哪」的單一真實來源，序列化只讀引擎狀態。
- **未採用之替代**：座標續留 `PlayerController`，存檔時由 `main.gd` 拉取、讀檔時推回。耦合較少，但 `GameState` 無法完整代表遊戲狀態，存檔邏輯會散落到呈現層。

## 元件（沿用既有「引擎純邏輯 / autoload 做 Godot 整合」分層）

| 元件 | 位置 | 型態 | 職責 |
|------|------|------|------|
| `SaveData` | `engine/save/save_data.gd` | RefCounted | 跨層交握的快照結構：`party`、`gold`、`map_id`、`player_pos`、`player_facing`、`cleared_encounters` |
| `SaveSerializer` | `engine/save/save_serializer.gd` | 純邏輯（無 FileAccess） | `to_dict(SaveData) -> Dictionary`、`from_dict(Dictionary) -> SaveData`。`Vector2i` → `[x,y]`、enum → int、含 `version` 欄位。**架構文件指名的 TDD roundtrip 對象** |
| `SaveSystem` | `autoload/save_system.gd` | autoload | `save_to_slot(n)`、`load_from_slot(n)`、`list_slots()`、`delete_slot(n)`、`has_slot(n)`。`capture()` 由 `GameState`+`MapManager` 組出 `SaveData`；讀檔時還原引擎狀態後 emit `loaded` 訊號（**自己不重建 3D 世界**）。檔案位於 `user://saves/slot_<n>.json` |
| `SaveMenu` | `presentation/ui/save_menu.gd` | CanvasLayer | 固定 5 個存檔槽（slot 0–4）的列表（隊伍摘要／金錢／地圖／時間戳／「空」）；存／讀／刪三動作，覆寫與刪除需確認；以選單鍵開啟，開啟時鎖玩家輸入（沿用 `set_enabled(false)`），戰鬥中禁用 |

`SaveSystem` 不給 `class_name`（避免與 autoload 名稱衝突），與既有 `GameState`／`MapManager` 一致。

## 地圖識別與遭遇清除

- **地圖 id**：`MapManager.load_text_file` 載入時設 `map_id` = 檔名主幹（`level01.txt` → `"level01"`）；新增 `MapManager.load_by_id(id)`，解析為 `res://content/maps/<id>.txt`。屬最小慣例式目錄，日後可長成正式 registry。
- **已清遭遇**：`GameState` 持有 `cleared_encounters: { map_id: [[x,y],…] }`。`main.gd` 勝利流程除了清掉當前 live map 的遭遇，另記到 `GameState`。載入／進入地圖時，`MapManager` 把已清座標從新解析出的 `MapData` 抹除。

## 資料流

- **存檔**：選單 → `SaveSystem.save_to_slot(n)` → `capture()` 讀 `GameState` → `SaveSerializer.to_dict` → 加 `meta` 表頭 → JSON → 寫檔。
- **讀檔**：選單 → `load_from_slot(n)` → 讀檔+解析 → `from_dict` → `SaveData` → 還原 `GameState` + `MapManager.load_by_id` + 套用已清遭遇 → emit `loaded` → `main.gd` 重建世界（`WorldBuilder.build`）並依 `GameState` 重新 `setup` `PlayerController` → HUD refresh。

## Schema（JSON）

```json
{ "version": 1,
  "meta": { "saved_at": "<iso>", "map_id": "level01", "gold": 120,
            "party": [{"name":"Gerard","level":3}] },
  "state": { "gold": 120, "map_id": "level01", "player_pos": [3,5], "player_facing": 1,
             "party": [{ "name":"…","char_class":"…","level":3,"hp":28,"hp_max":28,
                         "sp":0,"sp_max":0,"might":15,"intellect":12,"personality":12,
                         "endurance":14,"speed":13,"accuracy":13,"luck":11,
                         "condition":0,"experience":0 }],
             "cleared_encounters": { "level01": [[4,2],[7,9]] } } }
```

`meta` 刻意冗餘幾個欄位，讓存檔槽列表免完整反序列化即可顯示。

## 錯誤處理

- 槽位檔不存在 → `load_from_slot` 回 false，選單顯示為空，不崩潰。
- JSON 損毀／無法解析 → 回 false + 推訊息，**不動現有狀態**。
- `version` 不符 → 拒絕並提示（遷移掛鉤後續再做）。
- `user://saves/` 於首次存檔時建立。

## 測試策略

- **純單元（GUT，無 IO）**：`SaveSerializer` roundtrip，用完整隊伍（含一名 KO、屬性各異、跨多地圖的 cleared 集合）→ to_dict→from_dict 深度相等；邊界：空隊伍、無 cleared。`SaveData` 預設值。
- **引擎**：`MapManager.load_by_id` 的 id↔path 解析與 `map_id` 賦值；`GameState` 已清遭遇 mark/apply 輔助函式。
- **整合（用 `user://`）**：`save_to_slot`→`load_from_slot` 過磁碟 roundtrip；`list_slots`／`delete_slot`。
- **選單 UI**：手動／整合。

## 非目標（M5a 不做）

- 道具／裝備持久化（M5b 會擴充 schema）
- 法術狀態（M5c）
- 自動存檔、雲端存檔、存檔加密

## 受影響檔案

**新增**：`engine/save/save_data.gd`、`engine/save/save_serializer.gd`、`autoload/save_system.gd`、`presentation/ui/save_menu.gd`，及對應測試。

**修改**：
- `autoload/game_state.gd`：新增 `current_map_id` / `player_pos` / `player_facing` / `cleared_encounters` 與輔助函式。
- `autoload/map_manager.gd`：`map_id` 賦值、`load_by_id`、套用已清遭遇。
- `presentation/world/main.gd`：把座標同步進 `GameState`、處理 `loaded` 訊號重建世界、開啟選單、勝利時記錄已清遭遇。
- `project.godot`：註冊 `SaveSystem` autoload 與選單輸入動作。
