# 任務進度 on-screen（事件 popup + 持久追蹤器 + 可挑選追蹤）— 設計

- **日期**：2026-06-27
- **狀態**：設計待核可（spec review gate）
- **範圍**：任務階段事件時在畫面彈出瞬間提示（popup）；右上角小地圖下方常駐一個「追蹤中任務」進度面板；任務可在 J 任務日誌挑選追蹤；追蹤狀態存檔。建在既有任務系統（`GameState.quests`、`quests_changed`、`QuestProgress`、`QuestLog`、`MiniMap`）之上。

## 目標

- 接任務 / 階段推進 / 任務完成時，畫面**瞬間彈出**該事件文字（不必開 J 也看得到回饋）。
- 右上角（小地圖下方）**常駐**顯示「追蹤中任務」的標題 + 當前階段進度。
- 在 J 任務日誌可用方向鍵選任務、按鍵設為追蹤；接任務自動追蹤最近接的。
- 追蹤選擇**進存檔**（讀檔保留）。

## 非目標

- 不做任務地圖箭頭/路徑導引、不做全螢幕任務畫面。
- popup 不做點擊互動（純顯示、自動淡出）。
- 不改任務推進/獎勵邏輯（只加事件信號與 UI）。

## 核心決策（brainstorm 2026-06-27 拍板）

| 層面 | 決定 |
|------|------|
| 顯示方式 | popup（瞬間）+ 持久追蹤器（兩者都要） |
| 追蹤器位置 | **小地圖下方、右對齊**（右上區域） |
| 追蹤選擇 | 接任務**自動追蹤最近接的**；J 日誌方向鍵 + `T` 改追蹤 |
| 追蹤持久化 | `tracked_quest` **進存檔，升 VERSION 9** |
| popup 位置/時長 | 畫面**上方置中**橫幅、約 **2.5s** 淡出、多事件**排隊**依序顯示 |
| 事件 | 接取 / 階段推進 / 完成 三種都 emit |

## 元件

### 1. Event trigger — `GameState.signal quest_event(text: String)`
在既有三處 emit（與 message_log.push 並排）：
- `accept_quest`：`quest_event.emit(QuestProgress.accepted_message(def))`
- `_commit_quest` 推進：`quest_event.emit("任務更新：" + QuestProgress.stage_line(def, after, self))`
- `_commit_quest` 完成：`quest_event.emit(QuestProgress.completed_message(def))`

### 2. 追蹤狀態（`GameState`，存檔 v9）
- `var tracked_quest: String = ""`（持久）。
- `set_tracked_quest(id)`：設定（呼叫端傳進行中 id）後 `quests_changed.emit()`（追蹤器/日誌刷新）。
- `accept_quest`：`tracked_quest = id`（自動追蹤最近接的）。
- `_commit_quest` 完成時：若 `tracked_quest == id` → `retrack()`。
- `retrack()`：若 `tracked_quest` 非進行中 → 設為第一個進行中任務 id（無則 `""`）。
- 讀檔：main `_on_loaded` 呼叫 `GameState.retrack()`（還原的 tracked 若失效則改追進行中）。
- 查詢：`tracked_quest` + `is_quest_active` + `quest_resolver` + `self`(q) 供追蹤器/日誌用。

### 3. Popup — `presentation/ui/quest_toast.gd`（`class_name QuestToast extends CanvasLayer`）
- `show_notice(text: String)`：把 text 推入佇列；若沒在顯示就開始顯示（橫幅淡入→停留→淡出→下一則）。
- 版面：上方置中（anchor 比例，避開右上小地圖/追蹤器）；單則約 2.5s。
- 佇列邏輯（`_queue: Array[String]`、`_showing: bool`）抽成可測；`_draw`/動畫不做像素測試（HUD 慣例）。
- main 接 `GameState.quest_event → quest_toast.show_notice`。

### 4. 追蹤器 — `presentation/ui/quest_tracker.gd`（`class_name QuestTracker extends CanvasLayer`）
- 貼小地圖下方、右對齊：`offset_top = MARGIN + MiniMap.panel_side() + 間距`、右側 anchor 比例對齊（沿用 MiniMap 的右上定位慣例）。
- 顯示：若 `GameState.tracked_quest` 為進行中 → 標題 + `QuestProgress.stage_line(def, state, GameState)`（如「哥布林的威脅\n擊敗哥布林 1/3」）；否則隱藏。
- `refresh()`：main 接 `quests_changed → tracker.refresh`。純文字組裝抽 `static tracker_lines(tracked, resolver, q) -> Array`（可測）。

### 5. J 任務日誌可挑選追蹤（`QuestLog` 擴充）
- 加游標 `_cursor`（索引進行中任務）；`_unhandled_input`：`↑/↓` 移動游標（夾在進行中數）、`T` → `GameState.set_tracked_quest(active[_cursor])`。
- `summary_lines` 簽章加 `tracked: String, cursor: int`：進行中每條前綴 `>`（游標）與 `★`（追蹤中）標記。純可測。
- 進行中任務順序取自 quests dict 插入序（穩定），游標索引其子集。

### 6. 存檔 v9
- `SaveData.tracked_quest`；`save_serializer` to/from（純字串）、`VERSION 9`；`save_system` capture/apply 帶 tracked_quest。版本斷言 8→9。

### 7. main 接線
- `_ready`：建 `QuestToast`、`QuestTracker`（加 child）；`GameState.quest_event.connect(quest_toast.show_notice)`；`GameState.quests_changed` 既有 → 加 `quest_tracker.refresh`。
- `_on_loaded`：加 `GameState.retrack()` + `quest_tracker.refresh`。

## 測試

- `GameState`：accept emit quest_event(接取文字) + tracked_quest=id；推進/完成 emit 對應文字；完成且為 tracked → retrack 改追下一個進行中；set_tracked_quest；retrack 規則（失效→第一個進行中/空）。
- 存檔：tracked_quest round-trip、absent→""、version 9。
- `QuestToast`：佇列——連續 show_notice 入列、依序消化（佇列狀態斷言；不測動畫）。
- `QuestTracker`：`tracker_lines`——追蹤中→標題+階段行；無追蹤/失效→空。
- `QuestLog`：`summary_lines` 加 tracked/cursor 後的 `>`/`★` 標記、空任務不爆。
- popup/tracker/_draw 不做像素測試（HUD 慣例）。

## 驗收

- 全套綠；`./run.sh`：接任務→畫面上方彈「接下任務：…」、右上小地圖下方出現追蹤器；殺怪/撿物/抵達→彈「任務更新：…」且追蹤器同步；J 日誌 `↑↓` 選、`T` 改追蹤（★ 變更）；完成→彈「任務完成：…」、追蹤器改追下一個或消失；存讀檔保留追蹤。
