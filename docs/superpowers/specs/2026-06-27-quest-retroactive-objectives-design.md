# 任務目標改狀態式 + 接取追認（修「提前完成→卡死」）— 設計

- **日期**：2026-06-27
- **狀態**：設計已核可（使用者拍板 Approach A，指示直接實作 + commit + push）
- **問題**：任務目標原為「事件計數器」（只算 stage 啟用後的事件），但世界永久（一次性遭遇）。先殺哥布林再接任務 → 擊殺不計、遭遇已清除無法重打 → kill 階段永遠 0/3 卡死。
- **方向（Approach A）**：目標改「對持久玩家狀態查詢」（天生與順序無關、可追認）；接取任務時自動追認已完成階段。

## 目標滿足判定（state-based）

| 型別 | 判定 |
|------|------|
| kill | `kill_counts[monster] >= N`（新增持久擊殺總計） |
| collect | `inventory.count_of(item) >= N`（已狀態式） |
| reach | `is_explored(map, cell)`（已持久；含 3×3 揭示，故「到達該區」即算，刻意放寬、玩家友善） |
| talk | **不自動**——僅由對話 `advance_quest` 推進 |

## 新持久狀態

- `GameState.kill_counts: Dictionary`（`{monster_id:int}`），每場戰鬥勝利 `notify_kill` 時 +1（不分有無任務）。
- 任務 state **砍掉 `count`** → `{status, stage}`（kill 不再需 per-quest 計數）。
- 存檔升 **VERSION 7**，加 `kill_counts`、quest state 去 count。依「不需向後相容」：只接受 v7、舊檔不再載；既有版本斷言測試 6→7。

## QuestSystem（純，改寫）

state：`{ "status": "active"|"done", "stage": int }`。`q`（duck-typed 查詢）提供 `kill_count(id)->int`、`item_count(id)->int`、`is_explored(map_id, cell)->bool`。

- `initial_state() -> {status:"active", stage:0}`
- `is_complete(state) -> bool`
- `is_stage_satisfied(stage, q) -> bool`：依型別查 `q`；talk → false。
- `catch_up(def, state, q) -> Dictionary`：當前（非 talk）階段已滿足就連續進階；停在未滿足/talk/done。**回新 dict、不變更輸入**。
- `advance_talk(def, state, q) -> Dictionary`：當前是 talk → 進一階，再 `catch_up`。
- `_advance(def, ns)`：stage+1；超末端→done、stage 釘 stage_count。

## GameState（接線；`q` = GameState 自身）

- 新 query 方法：`kill_count(id)`（讀 kill_counts）、`item_count(id)`（包 `inventory.count_of`）；`is_explored(map_id,pos)` 已存在。
- `accept_quest(id)`：set initial + 接取 toast + emit，再 `_run(id,"recheck")`（catch_up 追認）。
- `advance_quest(id)`：`_run(id,"talk")`（advance_talk）。
- `notify_kill(monster_id)`：`kill_counts[m]++`，再對每個 active quest `_run(id,"recheck")`。
- `notify_enter(map_id,pos)` / `refresh_collect()`：對每個 active quest `_run(id,"recheck")`（reach 由 main 先 `mark_explored` 後生效；兩者皆為「重新評估」觸發，參數於 reach 已不需、保留以免動 main）。
- `_run(id, kind)`：active 才跑；取 def；`before=quests[id]`；`after` = talk→`advance_talk` / 否則→`catch_up`；`_commit_quest`。
- `_commit_quest`：以 status+stage 比對變化（已無 count）；done→發獎 + 完成 toast；否則「任務更新：」+ `stage_line`；emit。
- **`main.gd` 不改**（既有 notify_* 呼叫時機正確；發獎仍一次性由 _commit 偵測 done）。

## QuestProgress

- `stage_line(def, state, q) -> String`：kill 顯示 `min(q.kill_count(m), N)/N`、collect 顯示 `min(q.item_count(i), N)/N`（夾住）；reach/talk 顯示 desc；done→「已完成」。
- `accepted_message`/`completed_message` 不變。

## 存檔（v7）

- `SaveData.kill_counts`；`save_serializer` VERSION 7、to/from 加 `kill_counts`（值 coerce int）、quests to/from 去 count；`save_system` capture/apply 帶 kill_counts。

## 只動的檔案

`engine/quest/quest_system.gd`、`engine/quest/quest_progress.gd`、`autoload/game_state.gd`、`engine/save/save_data.gd`、`engine/save/save_serializer.gd`、`autoload/save_system.gd` + 對應測試（QuestSystem 改寫狀態式 + 追認案例；QuestProgress stage_line(q)；GameState 追認/tally/retroactive；save kill_counts + quest 去 count + 版本 6→7）。

## 取捨（已接受）

kill 採絕對總計 → 未來「殺 N 隻」任務若早已殺夠會接取即完成。對手工劇情可接受；日後要「殺 N 隻新的」再加 per-quest baseline 型別。

## 驗收

- 既有正向流程不變（接任務→殺/撿/到→回報→獎勵）。
- **修復**：先殺哥布林再接任務 → 接取時 kill 階段自動追認、跳到 collect（不卡死）；全做完再接 → 落在「回報」。
- 全套測試綠；headless boot 乾淨；人工 `./run.sh`。
