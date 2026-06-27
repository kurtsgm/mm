# 怪物實例 UUID + UUID 制擊殺目標 — 設計

- **日期**：2026-06-27
- **狀態**：設計待核可（spec review gate）
- **範圍**：給每個地圖遇抵（encounter 實例）一個穩定的 UUIDv7；任務的擊殺目標改成「對應一串遇抵 UUID、全部擊敗才算」，取代原本「按怪物型別+數量全域計數」。根治「殺別處同型怪也算進度」，並支援多目標（清巢穴 / 打多個 boss）。附帶 `/check-quest` 擴充：驗證 kill 目標↔遇抵 uid + 整任務自動跑通測試。

## 問題與釐清

- 使用者回報：接哥布林任務後,**殺掉城鎮 (town_oak 3,1) 看守寶箱的哥布林,任務的「殺哥布林」就達成了**（野外 wild_ne 那隻變得「對任務沒意義」）。
- 查核：**非地圖資料共用 bug**——`map.map_id` 由 `MapManager.load_by_id` 以檔名正確設定;`encounters` 是 per-map+per-pos,清除 `cleared_encounters[map_id]=[pos]` 也是 per-map。殺城鎮 (3,1) **不會**清掉野外 (1,1) 的遇抵實體。
- 真因：擊殺目標**按怪物型別全域計數**（`kill_counts["goblin"]`,encounter `"g"`=3 隻 goblin），城鎮那場 3 隻 goblin 就把「殺 3 哥布林」吃滿。
- 結論（使用者拍板）：怪物應**逐實例有唯一 id**,任務擊殺應**對應實例 id、可多個**。

## 核心決策

| 層面 | 決定 |
|------|------|
| 實例 id 來源 | **自動生成 UUIDv7**,寫回地圖 JSON（穩定、可被任務引用） |
| id 單位 | **一個遇抵格 = 一場戰鬥 = 一個 uid**（一場可含多隻同組怪,共用該 uid） |
| 擊殺模型 | **純實例制**：kill 階段 `targets:[uid…]`,全部擊敗才過。**移除型別+數量計數** |
| 擊敗追蹤 | `GameState.defeated_encounters`（uid set,持久）→ 精確、跨怪不互擾、可追認 |
| 移除 | `kill_counts` 型別計數（bug 來源） |
| 存檔 | 加 `defeated_encounters`、移除 `kill_counts`,升 **VERSION 8** |

## 非目標

- 不做「個別怪物（同組內每隻）各一 uid」——單位是遇抵格。
- 不保留「殺任 N 隻某型」計數模式（已移除）。
- 不做怪物重生。
- 不需向後相容（升 v8、舊存檔不再載）。

## 元件

### UUIDv7 產生器 — `engine/util/uuidv7.gd`
- `class_name Uuidv7`;`static func generate() -> String`。
- 48-bit 毫秒時戳（`int(Time.get_unix_time_from_system() * 1000.0)`）+ 版本 nibble `7` + 變體位 `10` + 其餘隨機（`randi()`）。輸出標準 `8-4-4-4-12` 小寫十六進位。
- 同一毫秒批次生成靠隨機位區分（74 隨機位,碰撞機率可忽略）。

### UUID 指派工具 — `tools/assign_encounter_uuids.gd`（CLI, extends SceneTree）
- 掃 `content/maps/*.json`,對每個 `type:"monster"` 但**缺 `id`** 的 entity 生成 UUIDv7、寫回該檔。
- 寫回採 `JSON.stringify(data, "\t")` 重排版（地圖 JSON 變為工具管理格式,屬資料檔,一次性 churn 可接受）。
- 已有 `id` 者不動（穩定）。執行：`godot --headless --path . --script res://tools/assign_encounter_uuids.gd`。
- **importer 不在載入時生成**（否則每次載入都變,任務引用會壞）——只讀作者/工具寫好的 `id`,缺則 uid=""（check-quest 會抓）。

### 地圖格式 / `MapData` / importer
- `monster` entity：`{type:"monster", pos:[x,y], encounter:"g", id:"<uuidv7>"}`。
- `MapData` 加 `@export var encounter_uids: Dictionary = {}`（`Vector2i -> String uid`),與既有 `encounters`（`pos->group`）並存;`get_encounter`/`has_encounter`/`clear_encounter` 不動;加 `get_encounter_uid(pos) -> String`。
- `map_importer` 的 `"monster"` 分支:讀 `id` 填入 `encounter_uids[pos]`（缺則不填/空字串）。

### `GameState`
- 加 `var defeated_encounters: Dictionary = {}`（`uid -> true`,持久）。
- `mark_encounter_defeated(uid)`、`is_defeated(uid) -> bool`。
- `notify_encounter_defeated(uid)`：mark 後對每個 active quest recheck（`catch_up`）。
- **移除** `kill_counts`、`kill_count()`、`notify_kill()`。
- query 介面（給 QuestSystem/QuestProgress）：`item_count(id)`（collect）、`is_defeated(uid)`（kill）。reach 走事件式 `advance_reach`、talk 走 `advance_talk`（皆不變）。

### `QuestDef`
- kill 階段正規化：`{type:"kill", targets:Array[String], desc}`。驗證 `targets` 為非空字串陣列,否則該 stage 違規→parse 回 null。移除 `monster`/`count`。

### `QuestSystem`
- `is_stage_satisfied` kill 分支：`for t in stage.targets: if not q.is_defeated(t): return false` → 全 true 才滿足。
- 其餘（catch_up 停在 reach/talk、advance_reach、advance_talk）不變。

### `QuestProgress`
- kill 顯示「<desc> X/N」：N=`targets.size()`,X=已擊敗的 target 數（用 q.is_defeated 數）。

### `main.gd`
- `_on_combat_finished` 勝利：`GameState.notify_encounter_defeated(MapManager.current_map.get_encounter_uid(_combat_pos))`（uid 空則略過）。移除舊的 `for m in _combat.monsters: GameState.notify_kill(...)`。

### 存檔（v8）
- `SaveData.defeated_encounters`;`save_serializer` 加 `defeated_encounters`（uid 陣列）、移除 `kill_counts`、`VERSION 8`;`save_system` capture/apply 帶 `defeated_encounters`、移除 kill_counts。
- 版本斷言測試 7→8。

### demo 內容
- 跑指派工具給所有遇抵補 uid（town_oak (3,1)、wild_ne (1,1)）。
- `goblin_menace` kill 階段 `targets = [wild_ne (1,1) 遇抵的 uid]`。城鎮哥布林是不同 uid → 殺它不再算。

### `/check-quest` 擴充
- 靜態：每個遇抵 `id` 為非空、**全域唯一**;每個 kill 階段 `targets` 非空、每個 uid 對應到某張地圖存在的遇抵。
- **整任務 flow 自動測試**（新 `QuestFlow.simulate(gs, def, qid)` + GUT 測試 `tests/content/test_quest_flows.gd`,CLI 也跑）：對每個 quest——新建 GameState、注入 resolver、accept,逐階段驅動對應事件（kill→`mark_encounter_defeated(每個 target uid)`;collect→`inventory.add`+`refresh_collect`;reach→`notify_enter(map,pos)`;talk→`advance_quest`),斷言最終 `is_quest_done` 且發了獎。任一 quest 跑不通→報錯。

## 測試

- `Uuidv7`：格式（8-4-4-4-12）、版本 nibble=7、批次唯一。
- `map_importer`：monster `id`→`encounter_uids`;缺 id 容忍。
- `MapData`：`get_encounter_uid`。
- `GameState`：`mark_encounter_defeated`/`is_defeated`/`notify_encounter_defeated` 推進任務。
- `QuestDef`：kill `targets` 解析;空/非陣列→null。
- `QuestSystem`：kill 全 target 才滿足;少一個 uid→不滿足;非當前 kill 階段不誤推。
- `QuestProgress`：kill「X/N」顯示。
- 存檔：`defeated_encounters` round-trip、無 `kill_counts`、version 8。
- 內容：`goblin_menace` kill targets 為合法存在 uid;town vs wild 遇抵 uid 不同。
- **使用者回報流程迴歸**：defeat 城鎮遇抵 uid ≠ 野外 uid → 野外任務 kill 不滿足;defeat 野外 uid → 滿足。
- **flow 自動測試**：所有 checked-in quest 可端到端完成。
- `/check-quest`：targets↔uid、uid 唯一、缺 uid 偵測。

## 驗收

- check-quest 0 error;全套綠。
- 人工 `./run.sh`：橡鎮接哥布林任務 → 殺城鎮看守哥布林**不**推進任務 → 到野外殺巢穴哥布林**才**推進 → 撿信物 → 踏巢穴最深處 → 回報拿獎。
