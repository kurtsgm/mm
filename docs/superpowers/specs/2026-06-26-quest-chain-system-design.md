# 任務鏈系統（Quest Chain）— 設計

- **日期**：2026-06-26
- **狀態**：設計待核可（spec review gate）
- **範圍**：建立資料驅動的任務系統——多階段線性任務鏈，每階段一個目標，支援四種目標型別（對話/旗標、收集/交付道具、擊殺怪物、抵達地點）；任務透過對話接取/回報（並提供專屬「任務給予物件」entity）；常駐可開關的任務日誌面板 + 訊息列 toast；任務狀態進存檔。
- **里程碑定位**：建在既有「對話/事件 runtime」（`DialogueData`/`DialogueRunner`/`DialogueCondition`/`DialogueEffects`、`GameState.flags`）、戰鬥勝利鉤子、進格 dispatch、寶箱、map importer entity、選單互斥慣例之上。

## 目標

- 玩家可在 town_oak 向 NPC 接取一條任務，依序完成四個階段（抵達 → 擊殺 → 收集 → 回報），回報後拿到獎勵。
- 任務隨時可在**任務日誌面板**查閱：進行中任務的當前階段描述與進度（如「擊敗哥布林 2/3」）、已完成任務。
- 接取/階段完成/任務完成皆推**訊息列 toast**。
- 任務狀態（進度、完成）**進存檔**，讀檔還原。
- 系統**資料驅動**：之後新增任務 = 丟一個 `content/quests/<id>.json` + 在地圖放 `questgiver` entity + 寫接/交對話，不必改引擎碼。

## 非目標（本期不做）

- **非線性 / 分支任務**：任務是線性階段鏈，不做分支、不做「任選其一」階段。
- **單階段多目標（AND/OR）**：每階段恰一個目標。
- **collect 的「自起算取得數」語意**：採「目前持有 ≥ N」輪詢語意（見下「四種目標」）；故 collect 目標用非消耗/獨特道具。「自接受後取得 N 個（含期間消耗）」語意延後。
- **任務專用道具類別**：demo 的 collect 沿用既有道具（`lucky_charm`）；`ItemDef.Category` 不新增 `QUEST` 類別（屬未來增量）。
- **任務給予物件的獨立 Y/N UI**：`questgiver` entity 重用既有 `DialogueOverlay`/`DialogueRunner`，不另做第二套互動 UI。
- **任務追蹤指引**（地圖箭頭 / minimap 任務 marker / 自動導航）：本期只做日誌面板 + 訊息列。
- **限時 / 失敗 / 可放棄任務**：任務一旦接取只有「進行中 → 完成」兩態，不可放棄、不會失敗。
- **新 autoload**：不新增 autoload，不改 `project.godot`。

## 核心決策（brainstorm 2026-06-26 拍板）

| 層面 | 決定 | 理由 |
|------|------|------|
| 目標型別 | 四型全包：talk（對話/旗標）、kill（擊殺）、collect（收集）、reach（抵達） | 使用者選定 |
| 任務結構 | 多階段**線性鏈**，每階段一個目標 | 使用者選定（符合「任務鏈」語意） |
| 完成與獎勵 | 完成最後一階段時自動發獎、標記 done；「回 NPC 回報」即最後一個 talk 階段 | 把獎勵當任務屬性、由系統在完成那刻發放，turn-in 不需特例 |
| 接取/回報 | 走對話：擴充 `DialogueEffects`(accept/advance) + `DialogueCondition`(quest require)；任何對話（含 `scene`）都能接/交 | 重用既有 runtime；同時滿足「全走對話」 |
| 任務給予物件 | 新 `questgiver` entity（可重複觸發、踩格開對話），內部就是開 DialogueOverlay | 滿足「專屬給予物件」但不另做 UI |
| 任務日誌 | 按鍵（`J`）開關的面板 + 訊息列 toast 並存 | 使用者選定 |
| 核心邏輯位置 | engine 純模組（`QuestDef`/`QuestSystem`/`QuestProgress`），無 Godot 依賴 | 可 TDD、與既有 engine 分層一致 |
| 狀態位置 | `GameState.quests`（鏡射 `flags`/`triggered_scenes`）；定義經注入 `quest_resolver: Callable` 取得 | GameState 是玩家狀態的家；resolver 注入鏡射既有 `SaveSystem.item_resolver`，讓 GameState 保持 catalog-free |
| 編排位置 | `GameState` 薄方法委派 `QuestSystem` + 自行發獎；事件由 `main.gd` 在既有鉤子餵入 | 不新增 autoload；事件源（戰鬥/進格/寶箱/對話）都已在 main |
| 存檔 | `GameState.quests` 加入序列化，VERSION 升 6 | 依「不需向後相容」guideline：直接升、不寫回退協商 |

## 架構與分層

### engine（純、無 Godot 依賴、TDD）

- **`engine/quest/quest_def.gd`（`class_name QuestDef extends RefCounted`）**
  - `static func parse(raw: Dictionary) -> QuestDef`：畸形 → `null`。
  - 欄位：`id: String`、`title: String`、`stages: Array`（每元素為一個 objective dict）、`rewards: Dictionary`（`{gold:int, items:Array[String]}`）。
  - 驗證：`stages` 須非空陣列；每個 stage 須有合法 `type`（talk/kill/collect/reach）與該型別必要參數（見下「目標 schema」），任一不合 → 整個 parse 回 null。
  - 輔助：`stage_count()`、`stage(i)->Dictionary`。

- **`engine/quest/quest_system.gd`（`class_name QuestSystem extends Object`，全 static 純函式）**
  - `static func initial_state() -> Dictionary` → `{ "status": "active", "stage": 0, "count": 0 }`。
  - `static func notify_kill(def, state, monster_id: String) -> Dictionary`：若當前階段為 kill 且 `monster` 相符 → `count+1`；達 `count`≥目標 → 進階（見下推進規則）。回傳新 state。
  - `static func notify_enter(def, state, map_id: String, pos: Vector2i) -> Dictionary`：若當前階段為 reach 且 `map`+`pos` 相符 → 進階。
  - `static func notify_advance(def, state) -> Dictionary`：若當前階段為 talk → 進階。
  - `static func check_collect(def, state, have_count_fn: Callable) -> Dictionary`：若當前階段為 collect 且 `have_count_fn.call(item) >= count` → 進階。
  - `static func is_complete(state) -> bool` → `state.status == "done"`。
  - **推進規則**：進階 = `stage+1`、`count` 歸 0；若 `stage` 已是最後一個 → `status="done"`。為讓呼叫端知道「剛剛是否完成 / 是否有進度變化」以決定發獎與 toast，函式以**比較前後 state** 判定（呼叫端比 `is_complete` 與 `stage` 差異），或回傳含 `{state, advanced, completed}` 的結果 dict（實作細節留給 plan，行為以本規則為準）。

- **`engine/quest/quest_progress.gd`（`class_name QuestProgress extends Object`，全 static）**
  - `static func stage_line(def, state, have_count_fn: Callable) -> String`：產生當前階段的人可讀進度行：
    - kill → 「<desc> <count>/<目標>」
    - collect → 「<desc> <擁有數>/<目標>」
    - reach / talk → 「<desc>」（無計數）
  - `static func accepted_message(def) -> String`、`stage_done_message(def, state) -> String`、`completed_message(def) -> String`：給訊息列的 toast 文字（含獎勵描述）。
  - 純可測；UI 的 `_draw`/節點渲染不做像素測試（沿用 HUD 慣例）。

### content（資料）

- **`content/quests/<id>.json`**：任務定義（schema 見下）。
- **`content/dialogues/<id>.json`**：任務給予/回報對話（用新的 quest ops/require）。

### presentation（Godot 節點）

- **`presentation/world/quest_catalog.gd`（`class_name QuestCatalog`）**：`static func load_quest(id) -> QuestDef`，讀 `res://content/quests/<id>.json` → `QuestDef.parse`，缺檔/畸形 → null。鏡射 `DialogueCatalog`。
- **`presentation/ui/quest_log.gd`（`class_name QuestLog extends CanvasLayer`）**：`J` 鍵開關的任務日誌面板。`is_open()/open()/close()`、`signal closed`，加入 main 的 `_menus` 互斥。聽 `GameState.quests_changed` 刷新。版面**比例式**（依 CLAUDE.md「UI 版面一律依視窗比例」）。

### autoload / glue

- **`autoload/game_state.gd`** 擴充（見下）。

## 資料模型

### 任務 JSON schema（`content/quests/<id>.json`）

```json
{
  "id": "goblin_menace",
  "title": "哥布林的威脅",
  "stages": [
    { "type": "reach",   "map": "wild_ne", "pos": [1, 1], "desc": "前往哥布林巢穴" },
    { "type": "kill",    "monster": "goblin", "count": 3, "desc": "擊敗哥布林" },
    { "type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得哥布林信物" },
    { "type": "talk",    "desc": "回橡鎮向守衛回報" }
  ],
  "rewards": { "gold": 100, "items": ["potion"] }
}
```

**各目標 schema**
- `reach`：`map: String`、`pos: [x,y]`、`desc`。
- `kill`：`monster: String`（怪物 id）、`count: int>0`、`desc`。
- `collect`：`item: String`（道具 id）、`count: int>0`、`desc`。
- `talk`：`desc`（無其他必要參數；由對話 `advance_quest` 觸發）。

### 存檔狀態（`GameState.quests`）

```gdscript
# quest_id -> { "status": "active"|"done", "stage": int, "count": int }
var quests: Dictionary = {}
```
- 純 JSON 友善（String key、String/int value，無 Vector2i），序列化比 `triggered_scenes` 更單純。
- 存檔：`SaveData.quests` 加入 `to_dict`/`from_dict`；**VERSION 升 6**；缺鍵走一般 `.get("quests", {})` 預設（屬一般缺鍵預設，非版本協商回退）。

## 四種目標的判定與推進

| 型別 | 推進來源（main 鉤子） | 機制 |
|---|---|---|
| **kill** | `_on_combat_finished` 勝利分支 | 每擊敗一隻 → `GameState.notify_kill(def_id)`；比對 `monster`，`count++`，達標進階 |
| **reach** | `_on_entered_cell` 頂部（無條件） | `GameState.notify_enter(map_id, pos)`；比對 `map`+`pos`，命中進階 |
| **collect** | 檢查點輪詢 | `GameState.refresh_collect()` 在開寶箱後、戰鬥後、對話後、進格時呼叫；當前 collect 階段 `inventory.count(item) ≥ N` → 進階 |
| **talk** | 對話 op | `advance_quest` → `GameState.advance_quest(id)`；當前為 talk 階段才進階；若為最後階段 → 完成 + 發獎 |

**collect 語意限制（明確）**：採「目前背包持有 ≥ N」輪詢，**非**「自接受後取得 N 個」。後果：(a) 接受任務當下若已持有該道具，collect 階段在下次檢查點即自動完成；(b) 若道具被消耗會「倒退」失去達成（但只要尚未進到下一階段才有影響——一旦進階就不回頭）。故 collect 目標**用非消耗/獨特道具**（demo 用 `lucky_charm`，玩家不會起始持有、不是消耗品）。

## 對話整合

### `DialogueEffects` 新增 op（套在 `ctx`，ctx 即 GameState）
- `{ "op": "accept_quest",  "quest": "<id>" }` → `ctx.accept_quest("<id>")`（已接/已完成則無動作；冪等）。
- `{ "op": "advance_quest", "quest": "<id>" }` → `ctx.advance_quest("<id>")`（當前 talk 階段才推進）。
- 兩者回人可讀描述進 `out`（如「接下任務：哥布林的威脅」），與既有 op 一致進訊息列。

### `DialogueCondition` 新增 require key（讀 `ctx.is_quest_*`）
- `{ "quest_inactive": "<id>" }`：尚未接取（不在 quests）→ true。用於只在接取前顯示「接任務」選項。
- `{ "quest_active": "<id>" }`：status == active → true。
- `{ "quest_done": "<id>" }`：status == done → true。
- `{ "quest_stage": { "id": "<id>", "eq": <int> } }`：active 且當前 stage == eq → true。用於只在最後 talk 階段顯示「回報」選項。
- 未知鍵維持既有保守行為（→ false）。

### 任務給予物件（`questgiver` entity）
- 地圖 `entities`：`{ "type": "questgiver", "pos": [x,y], "dialogue": "<dialogue_id>" }`。
- `map_importer` 解析 → `MapData.quest_givers: Array`（`{pos, dialogue}`），畸形（缺 dialogue / pos 非法）→ 跳過該 entity。
- `MapData` 加 `has_quest_giver(pos)`、`get_quest_giver(pos)`（線性掃描，鏡射 `scenes`/`vendors`）。
- main `_try_quest_giver(pos)`：命中 → `_dialogue_overlay.open(DialogueRunner.new(QuestDialogueData, GameState))`（與 `_try_scene` 同路徑，但**可重複觸發、無 `once`**）。
- 一個 questgiver 的對話依 quest require 顯示不同節點/選項：未接 → 提供接取；進行中（最後 talk 階段）→ 提供回報；已完成 → 感謝詞。

## main.gd 接線（皆在既有鉤子）

- `_ready()`：
  - 注入 `GameState.quest_resolver = Callable(QuestCatalog, "load_quest")`。
  - 建 `QuestLog` 節點、`J` 鍵綁定、加入 `_menus`。
  - 連 `GameState.quests_changed` → `quest_log.refresh`（面板開著時即時更新）。
- `_on_entered_cell(pos)`：
  - **頂部無條件**呼叫 `GameState.notify_enter(MapManager.map_id, pos)` 與 `GameState.refresh_collect()`（reach 不應被 dispatch 早退擋掉）。
  - dispatch 鏈插入 `_try_quest_giver`：`link → encounter → chest → scene → questgiver → vendor → tile`。
- `_on_combat_finished` 勝利分支：對每隻擊敗怪 `GameState.notify_kill(<monster def id>)`，最後 `GameState.refresh_collect()`（掉落可能滿足 collect）。
- 開寶箱發道具後（`_on_chest_confirmed` grant 之後）：`GameState.refresh_collect()`。
- 對話結束（`_on_dialogue_finished` / advanced）：accept/advance op 已即時改 state、發 toast、emit `quests_changed`；另呼叫 `refresh_collect()`（give op 可能給了 collect 道具）。
- modal 守門：QuestLog 開啟時，`_unhandled_input` 早退（沿用既有選單慣例）。

## GameState 擴充（薄包裝）

```gdscript
var quests: Dictionary = {}        # id -> {status, stage, count}
var quest_resolver: Callable       # 注入：Callable(QuestCatalog, "load_quest")
signal quests_changed

func accept_quest(id) -> void          # 取 def、若可接 → quests[id]=initial_state；toast；emit
func advance_quest(id) -> void         # talk 推進；完成 → 發獎；toast；emit
func notify_kill(monster_id) -> void   # 對所有 active 任務嘗試推進；完成 → 發獎；toast；emit
func notify_enter(map_id, pos) -> void # 同上（reach）
func refresh_collect() -> void         # 同上（collect，輪詢 inventory）
func is_quest_active(id) -> bool
func is_quest_done(id) -> bool
func is_quest_inactive(id) -> bool
func quest_stage(id) -> int            # active 回 stage，否則 -1
```
- 發獎：`gold += rewards.gold`、`inventory.add(item,1)`、`message_log.push(...)`——皆 GameState 已持有。
- 重邏輯（階段判定/推進）在純 `QuestSystem`；GameState 方法只取 def（resolver）、呼叫 QuestSystem、套用結果、emit signal。

## 任務日誌 UI（`QuestLog`）

- `CanvasLayer`，`J` 鍵開關、加入 `_menus` 互斥（現有 `Tab`=存檔、`I`=背包、`M`=法術；`J` 未佔用）。
- 內容：
  - 進行中：每任務一行（區）顯示 `title` + `QuestProgress.stage_line(...)`（如「擊敗哥布林 2/3」）。
  - 已完成：標題列於「已完成」區、淡色。
- 聽 `GameState.quests_changed` 刷新；開啟時也刷新。
- 版面 anchor 比例式、字級可固定（依 CLAUDE.md UI 規則）。

## Demo 任務內容「哥布林的威脅」（`goblin_menace`）

- **接取**：`town_oak` 守衛 `questgiver`（FLOOR 格，避開 start/portal/既有 entity），對話 `qg_oak_guard`（依 quest require 顯示 接取 / 回報 / 感謝）。
- **階段1 reach**：前往 `wild_ne` 哥布林巢穴某 FLOOR 格。
- **階段2 kill**：擊敗 3 隻 `goblin`（`wild_ne` 補放 goblin encounters；可為一場 3 隻或多場）。
- **階段3 collect**：取得 `lucky_charm`（`wild_ne` 巢穴放一個含 `lucky_charm` 的寶箱）。
- **階段4 talk**：回 `town_oak` 守衛回報 → 完成 → 獎勵 `gold 100` + `potion ×1`。

新增內容檔：`content/quests/goblin_menace.json`、`content/dialogues/qg_oak_guard.json`；`town_oak.json` 加 `questgiver` entity；`wild_ne.json` 加 goblin encounters + 含 lucky_charm 的 chest + reach 目標格為可走 FLOOR。

## 測試（GUT，沿用慣例）

- `QuestDef.parse`：合法解析、各畸形（空 stages、未知 type、缺必要參數、rewards 缺省）→ null。
- `QuestSystem`：四型推進、kill 計數達標、collect 輪詢、reach/talk 比對、最後階段 → done、非當前型別事件不誤推進。
- `QuestProgress`：各型別 stage_line 文字、toast 文字（含獎勵）。
- `DialogueCondition`：新 require（quest_active/done/inactive/quest_stage）真假值。
- `DialogueEffects`：accept_quest/advance_quest 改 ctx 狀態 + 回描述。
- `map_importer`：questgiver entity 解析、畸形跳過。
- `MapData`：has/get_quest_giver。
- `GameState`（鏡射 `test_game_state_flags.gd`）：accept/advance/notify_kill/notify_enter/refresh_collect 改 quests、完成發獎（gold/inventory/message）、emit quests_changed、查詢 helper。
- 存檔 round-trip：含 quests 的存讀檔還原（含 in-progress 與 done）。
- 內容驗證：`goblin_menace.json` 可被 QuestCatalog 載入且通過 QuestDef.parse；demo 對話可載入。

## 風險與緩解

- **collect「目前持有」語意誤觸**：以 demo 用非消耗/獨特道具規避；spec 明列限制，作者須遵守（未來再加「自起算」語意）。
- **reach 與 dispatch 早退衝突**：`notify_enter` 放 `_on_entered_cell` 頂部、與 dispatch 鏈獨立，確保 reach 目標即使該格還有別的 entity 也能達成；demo 的 reach 目標選純 FLOOR 格避免疑慮。
- **多階段 talk 的歧義**：線性鏈只有「當前階段」可推進，`advance_quest` 對應唯一當前 talk 階段，無歧義。
- **存檔 v6**：依「不需向後相容」guideline，直接升版、不寫回退；舊檔壞掉可接受。

## 視覺驗收 gate（待人工 `./run.sh`）

1. town_oak 踩守衛格 → 對話接任務 → 訊息列「接下任務」、`J` 開日誌見「前往哥布林巢穴」。
2. 進 wild_ne 巢穴格 → 日誌推進到「擊敗哥布林 0/3」。
3. 打 3 隻哥布林 → 日誌「2/3 → 3/3 → 進階」、訊息列階段完成 toast。
4. 開巢穴寶箱拿 lucky_charm → collect 階段完成、進到「回橡鎮回報」。
5. 回 town_oak 守衛 → 回報 → 任務完成 toast、金幣 +100、得 potion、日誌移到「已完成」。
6. 全程任一點存檔 → 讀檔後任務進度/完成狀態還原。
