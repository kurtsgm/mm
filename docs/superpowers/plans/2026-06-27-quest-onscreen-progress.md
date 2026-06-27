# 任務進度 on-screen Implementation Plan

> **✅ 狀態：已全部實作完成（2026-06-27）。** 本計畫 6 個 task 皆已落地並 commit 於 `main`（在戰鬥 UI 工作之前）：Task 1 `dd6181b`、Task 2 `a953cb1`、Task 3 `165d709`、Task 4 `50078bf`、Task 5 `0a09750`、Task 6 `e52fec8`。相關測試全綠（quest_toast/quest_tracker/quest_log/game_state_quests/save_serializer_quests 共 32 例）。下方未勾選的 checkbox 為原始撰寫狀態，**不代表未完成**——本文件保留作實作紀錄。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 任務事件時畫面彈出瞬間提示（popup），右上小地圖下方常駐「追蹤中任務」進度面板，J 任務日誌可挑選追蹤，追蹤狀態進存檔。

**Architecture:** `GameState` 加 `signal quest_event(text)` 與持久 `tracked_quest`；新 `QuestToast`(上方置中橫幅、排隊淡出) 接 quest_event；新 `QuestTracker`(小地圖下方) 與 `QuestLog`(加游標/★) 讀 tracked_quest，聽 `quests_changed` 刷新；存檔升 v9。

**Tech Stack:** Godot 4.7、GDScript、GUT。

## Global Constraints

- **不需向後相容**：save VERSION 直接升 9、舊檔不再載；一併改測試。
- **UI 版面比例式**（anchor 比例，不寫死像素）；字級/小間距可固定。tracker 貼小地圖下方可用 `MiniMap.MARGIN`+`MiniMap.panel_side()`（小地圖本就固定尺寸面板）。
- **溝通語言**：所有使用者可見字串繁體中文。
- 新增 `class_name` 腳本後先 `godot --headless --path . --import` 再跑 GUT；`.gd.uid` 一併 commit。
- 測試指令：全套 `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`；單檔 `-gselect=<file>.gd`（此專案 `-gtest=` 會跑全套）。
- **q（duck-typed）契約**：`q.is_defeated(uid)->bool`、`q.item_count(id)->int`、`q.is_quest_active(id)->bool`、`q.quests`（id→state dict）。QuestProgress.stage_line(def,state,q) 已存在。
- 既有事件文字：接取=`QuestProgress.accepted_message(def)`、推進=`"任務更新：" + QuestProgress.stage_line(def, after, self)`、完成=`QuestProgress.completed_message(def)`。

---

## 檔案結構

**新增**：`presentation/ui/quest_toast.gd`、`presentation/ui/quest_tracker.gd`、`tests/presentation/test_quest_toast.gd`、`tests/presentation/test_quest_tracker.gd`。
**修改**：`autoload/game_state.gd`、`engine/save/save_data.gd`、`engine/save/save_serializer.gd`、`autoload/save_system.gd`、`presentation/ui/quest_log.gd`、`presentation/world/main.gd` + 既有測試（test_game_state_quests、save 版本、test_quest_log）。

---

## Task 1: GameState — quest_event 信號 + tracked_quest + 自動追蹤/retrack

**Files:** Modify `autoload/game_state.gd`；Test `tests/autoload/test_game_state_quests.gd`

**Interfaces:** Produces `GameState`：`signal quest_event(text: String)`、`var tracked_quest: String`、`set_tracked_quest(id)`、`retrack()`；accept 自動設 tracked + emit quest_event；_commit emit quest_event、完成且為 tracked 時 retrack。

- [ ] **Step 1: 失敗測試** — `tests/autoload/test_game_state_quests.gd` 加（沿用既有 `_gs()`/`_resolve`/`before_each` 的 `_def`，kill targets `["u-wild"]`）：

```gdscript
func test_accept_sets_tracked_and_emits_event():
	var gs = _gs()
	watch_signals(gs)
	gs.accept_quest("q")
	assert_eq(gs.tracked_quest, "q")
	assert_signal_emitted_with_parameters(gs, "quest_event", ["接下任務：哥布林的威脅"])

func test_advance_emits_quest_event():
	var gs = _gs()
	gs.accept_quest("q")
	watch_signals(gs)
	gs.notify_encounter_defeated("u-wild")   # kill 滿足 → 推進到 collect
	assert_signal_emitted(gs, "quest_event")

func test_set_tracked_quest_active_only():
	var gs = _gs()
	gs.accept_quest("q")
	gs.set_tracked_quest("nope")     # 非進行中 → 不變
	assert_eq(gs.tracked_quest, "q")

func test_retrack_to_next_active_on_complete():
	var gs = _gs()
	gs.accept_quest("q")             # tracked = q
	# 完成 q：殺→撿→到→回報
	gs.notify_encounter_defeated("u-wild")
	gs.inventory.add("lucky_charm", 1); gs.refresh_collect()
	gs.notify_enter("wild_ne", Vector2i(3, 3))
	gs.advance_quest("q")
	assert_true(gs.is_quest_done("q"))
	assert_eq(gs.tracked_quest, "")  # 無其他進行中 → 清空

func test_retrack_picks_first_active():
	var gs = _gs()
	gs.tracked_quest = "ghost"       # 失效 id
	gs.quests["q"] = QuestSystem.initial_state()  # 直接塞一個進行中
	gs.retrack()
	assert_eq(gs.tracked_quest, "q")
```

- [ ] **Step 2: 跑→失敗**：`-gselect=test_game_state_quests.gd` → FAIL（quest_event/tracked_quest/set_tracked_quest/retrack 不存在）

- [ ] **Step 3: 實作** — `autoload/game_state.gd`：
變數區 `var quest_resolver...` 之後加：

```gdscript
var tracked_quest: String = ""     # 追蹤中任務 id（持久；"" = 無）
```
`signal quests_changed` 之後加：

```gdscript
signal quest_event(text: String)   # 接取/推進/完成的瞬間提示文字（給 popup）
```
`accept_quest` 改（自動追蹤 + emit；accepted 文字算一次）：

```gdscript
func accept_quest(id: String) -> void:
	if quests.has(id):
		return  # 已接/已完成，冪等
	var def = _quest_def(id)
	if def == null:
		return
	quests[id] = QuestSystem.initial_state()
	tracked_quest = id
	var msg := QuestProgress.accepted_message(def)
	message_log.push(msg)
	quest_event.emit(msg)
	quests_changed.emit()
	_run_quest(id, "recheck")
```
`_commit_quest` 改（emit quest_event；完成且為 tracked → retrack）：

```gdscript
func _commit_quest(id: String, def, before: Dictionary, after: Dictionary) -> void:
	var changed: bool = after["status"] != before["status"] or after["stage"] != before["stage"]
	if not changed:
		return
	quests[id] = after
	var text: String
	if String(after["status"]) == "done":
		_grant_quest_rewards(def)
		text = QuestProgress.completed_message(def)
		if tracked_quest == id:
			retrack()
	else:
		text = "任務更新：" + QuestProgress.stage_line(def, after, self)
	message_log.push(text)
	quest_event.emit(text)
	quests_changed.emit()
```
在 `_quest_def` 之前（或任務區任一處）加：

```gdscript
func set_tracked_quest(id: String) -> void:
	if is_quest_active(id):
		tracked_quest = id
		quests_changed.emit()

# 追蹤中任務若已非進行中 → 改追第一個進行中任務（無則清空）。
func retrack() -> void:
	if is_quest_active(tracked_quest):
		return
	tracked_quest = ""
	for id in quests.keys():
		if is_quest_active(id):
			tracked_quest = id
			return
```

- [ ] **Step 4: 跑→通過**（`-gselect=test_game_state_quests.gd`）

- [ ] **Step 5: Commit**：`git add autoload/game_state.gd tests/autoload/test_game_state_quests.gd && git commit -m "feat(quest): GameState quest_event 信號 + tracked_quest 自動追蹤/retrack"`

---

## Task 2: 存檔 v9（tracked_quest）

**Files:** Modify `engine/save/save_data.gd`、`engine/save/save_serializer.gd`、`autoload/save_system.gd`；Test `tests/engine/save/test_save_serializer_quests.gd` + 版本斷言三檔

**Interfaces:** Produces `SaveData.tracked_quest: String`；序列化 `state.tracked_quest`；`VERSION==9`。

- [ ] **Step 1: 改測試** — `tests/engine/save/test_save_serializer_quests.gd`：`_data()` 加 `d.tracked_quest = "q"`；加：

```gdscript
func test_tracked_quest_round_trip():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_data()))
	assert_eq(back.tracked_quest, "q")

func test_tracked_quest_absent_is_empty():
	var raw := SaveSerializer.to_dict(_data())
	raw["state"].erase("tracked_quest")
	assert_eq(SaveSerializer.from_dict(raw).tracked_quest, "")
```
`test_version_is_8`→`test_version_is_9`/斷言 9；`test_old_version_rejected` 的 `raw["version"]=7`→`=8`。
版本斷言三檔：`test_save_serializer.gd` `test_to_dict_version_is_8`→9、`test_save_serializer_flags.gd` `test_version_is_8`→9、`test_save_serializer_spells.gd` `test_version_is_8`→9（函式名與值都改 9）。

- [ ] **Step 2: 跑→失敗**（`-gdir=res://tests/engine/save`）

- [ ] **Step 3: 實作**
`engine/save/save_data.gd`：`var defeated_encounters...` 之後加 `var tracked_quest: String = ""`。
`engine/save/save_serializer.gd`：`const VERSION := 8`→`9`；to_dict 的 state 內 `"quests": ...,` 之後加 `"tracked_quest": data.tracked_quest,`；from_dict 的 `data.quests = ...` 之後加 `data.tracked_quest = String(s.get("tracked_quest", ""))`。
`autoload/save_system.gd`：`data.quests = gs.quests` 之後加 `data.tracked_quest = gs.tracked_quest`；`gs.quests = data.quests` 之後加 `gs.tracked_quest = data.tracked_quest`。

- [ ] **Step 4: 跑→通過**（`-gdir=res://tests/engine/save`）

- [ ] **Step 5: Commit**：`git add engine/save/ autoload/save_system.gd tests/engine/save/ && git commit -m "feat(quest): 存檔 v9 tracked_quest"`

---

## Task 3: QuestToast（事件 popup）

**Files:** Create `presentation/ui/quest_toast.gd`；Test `tests/presentation/test_quest_toast.gd`

**Interfaces:** Produces `class_name QuestToast extends CanvasLayer`；`func show_notice(text: String)`（入列、依序顯示）。

- [ ] **Step 1: 失敗測試** — `tests/presentation/test_quest_toast.gd`：

```gdscript
extends GutTest

func test_queue_shows_first_holds_rest():
	var t := QuestToast.new()
	add_child_autofree(t)
	t.show_notice("甲")
	t.show_notice("乙")
	assert_eq(t._label.text, "甲")    # 第一則顯示中
	assert_eq(t._queue, ["乙"])       # 後續排隊
	assert_true(t._showing)

func test_idle_when_empty():
	var t := QuestToast.new()
	add_child_autofree(t)
	assert_false(t._showing)
	assert_false(t.visible)
```

- [ ] **Step 2: 跑→失敗**（`-gselect=test_quest_toast.gd`）→ FAIL（QuestToast 未定義）

- [ ] **Step 3: 實作** — `presentation/ui/quest_toast.gd`：

```gdscript
class_name QuestToast
extends CanvasLayer
# 任務事件瞬間提示：畫面上方置中橫幅，淡入即顯→停留→淡出，多則依序排隊。
# 佇列狀態（_queue/_showing）可單元測；_draw/動畫不做像素測試（HUD 慣例）。

const HOLD := 2.5      # 單則停留秒數

var _queue: Array[String] = []
var _showing: bool = false
var _panel: Panel
var _label: Label

func show_notice(text: String) -> void:
	_queue.append(text)
	if not _showing:
		_advance()

func _ready() -> void:
	layer = 11
	visible = false
	_panel = Panel.new()
	_panel.anchor_left = 0.25
	_panel.anchor_right = 0.75
	_panel.anchor_top = 0.06
	_panel.anchor_bottom = 0.13
	add_child(_panel)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 20)
	_panel.add_child(_label)

func _advance() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	_showing = true
	_label.text = _queue.pop_front()
	visible = true
	_panel.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(HOLD)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_advance)
```
（注意：`show_notice` 同步入列並在閒置時 `_advance` 立即設定 `_label.text`/`_showing`；tween 在後續 idle frame 才推進，故測試可在同步呼叫後立即斷言佇列狀態。）

- [ ] **Step 4: import + 跑→通過**：`godot --headless --path . --import` 然後 `-gselect=test_quest_toast.gd`

- [ ] **Step 5: Commit**：`git add presentation/ui/quest_toast.gd presentation/ui/quest_toast.gd.uid tests/presentation/test_quest_toast.gd tests/presentation/test_quest_toast.gd.uid && git commit -m "feat(quest): QuestToast 事件 popup（上方置中、排隊淡出）"`

---

## Task 4: QuestTracker（小地圖下方追蹤器）

**Files:** Create `presentation/ui/quest_tracker.gd`；Test `tests/presentation/test_quest_tracker.gd`

**Interfaces:** Consumes `MiniMap.MARGIN`/`MiniMap.panel_side()`、`QuestProgress.stage_line`、q 契約。Produces `class_name QuestTracker extends CanvasLayer`；`func refresh()`；`static func tracker_lines(tracked: String, resolver: Callable, q) -> Array`。

- [ ] **Step 1: 失敗測試** — `tests/presentation/test_quest_tracker.gd`：

```gdscript
extends GutTest

class FakeQ:
	var quests: Dictionary = {}
	var defeated: Dictionary = {}
	var items: Dictionary = {}
	func is_quest_active(id: String) -> bool:
		return quests.has(id) and String(quests[id].get("status", "")) == "active"
	func is_defeated(uid: String) -> bool: return defeated.has(uid)
	func item_count(id: String) -> int: return int(items.get(id, 0))

var _def: QuestDef
func _resolve(id) -> QuestDef: return _def if id == "q" else null

func before_each():
	_def = QuestDef.parse({
		"id": "q", "title": "哥布林的威脅",
		"stages": [
			{"type": "kill", "targets": ["u-a"], "desc": "擊敗哥布林"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 10, "items": []},
	})

func test_tracker_lines_shows_title_and_stage():
	var q := FakeQ.new(); q.quests["q"] = {"status": "active", "stage": 0}
	var lines := QuestTracker.tracker_lines("q", Callable(self, "_resolve"), q)
	var joined := "\n".join(lines)
	assert_true(joined.contains("哥布林的威脅"))
	assert_true(joined.contains("擊敗哥布林 0/1"))

func test_tracker_lines_empty_when_none():
	assert_eq(QuestTracker.tracker_lines("", Callable(self, "_resolve"), FakeQ.new()), [])

func test_tracker_lines_empty_when_not_active():
	var q := FakeQ.new(); q.quests["q"] = {"status": "done", "stage": 2}
	assert_eq(QuestTracker.tracker_lines("q", Callable(self, "_resolve"), q), [])
```

- [ ] **Step 2: 跑→失敗**（`-gselect=test_quest_tracker.gd`）

- [ ] **Step 3: 實作** — `presentation/ui/quest_tracker.gd`：

```gdscript
class_name QuestTracker
extends CanvasLayer
# 小地圖下方常駐「追蹤中任務」面板：標題 + 當前階段進度。無追蹤/失效則隱藏。
# 文字組裝抽 tracker_lines（純可測）；版面貼小地圖下方、右對齊。

var _panel: Panel
var _label: Label

func _ready() -> void:
	layer = 9
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var side := MiniMap.panel_side()
	_panel.offset_top = MiniMap.MARGIN + side + 8
	_panel.offset_bottom = MiniMap.MARGIN + side + 8 + 60
	_panel.offset_left = -MiniMap.MARGIN - side
	_panel.offset_right = -MiniMap.MARGIN
	add_child(_panel)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 8
	_label.offset_top = 6
	_label.offset_right = -8
	_label.offset_bottom = -6
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 15)
	_panel.add_child(_label)
	refresh()

func refresh() -> void:
	var lines := tracker_lines(GameState.tracked_quest, GameState.quest_resolver, GameState)
	visible = not lines.is_empty()
	if visible:
		_label.text = "\n".join(lines)

static func tracker_lines(tracked: String, resolver: Callable, q) -> Array:
	if tracked == "" or not resolver.is_valid() or not q.is_quest_active(tracked):
		return []
	var def = resolver.call(tracked)
	if def == null:
		return []
	var state: Dictionary = q.quests[tracked]
	return ["◈ " + def.title, QuestProgress.stage_line(def, state, q)]
```

- [ ] **Step 4: import + 跑→通過**（`-gselect=test_quest_tracker.gd`）

- [ ] **Step 5: Commit**：`git add presentation/ui/quest_tracker.gd presentation/ui/quest_tracker.gd.uid tests/presentation/test_quest_tracker.gd tests/presentation/test_quest_tracker.gd.uid && git commit -m "feat(quest): QuestTracker 小地圖下方追蹤器"`

---

## Task 5: QuestLog 可挑選追蹤（游標 + ★）

**Files:** Modify `presentation/ui/quest_log.gd`；Test `tests/presentation/test_quest_log.gd`

**Interfaces:** Consumes `GameState.set_tracked_quest`/`tracked_quest`/`is_quest_active`。Produces `summary_lines(quests, resolver, q, tracked := "", cursor := -1)`（進行中標 `>` 游標 / `★` 追蹤）；`↑/↓` 移游標、`T` 設追蹤。

- [ ] **Step 1: 改測試** — `tests/presentation/test_quest_log.gd`：把 `_def()` kill 改 targets（FakeQ 已是 defeated/is_defeated）。加：

```gdscript
func test_summary_marks_tracked_and_cursor():
	var quests := {"q": {"status": "active", "stage": 0}}
	var q := FakeQ.new()
	var lines := QuestLog.summary_lines(quests, Callable(self, "_resolve"), q, "q", 0)
	var joined := "\n".join(lines)
	assert_true(joined.contains("★"))   # 追蹤標記
	assert_true(joined.contains(">"))   # 游標
```
（既有 `test_summary_lists_active_with_progress` 等用 3 參數呼叫，靠新預設 `tracked=""`/`cursor=-1` 仍通過——確認其斷言只 contains 標題/階段字串。）

- [ ] **Step 2: 跑→失敗**（`-gselect=test_quest_log.gd`）

- [ ] **Step 3: 實作** — `presentation/ui/quest_log.gd`：
頂部加 `var _cursor: int = 0`。
`summary_lines` 整個換成（加 tracked/cursor、進行中逐條標記）：

```gdscript
static func summary_lines(quests: Dictionary, resolver: Callable, q, tracked := "", cursor := -1) -> Array:
	var active_ids: Array = []
	var done: Array[String] = []
	for id in quests:
		var def = resolver.call(id) if resolver.is_valid() else null
		if def == null:
			continue
		if String(quests[id].get("status", "")) == "done":
			done.append("✓ %s" % def.title)
		else:
			active_ids.append(id)
	var lines: Array[String] = ["== 任務日誌 ==  [↑↓]選 [T]追蹤 [J/Esc]關"]
	lines.append("-- 進行中 --")
	if active_ids.is_empty():
		lines.append("（無）")
	else:
		for i in active_ids.size():
			var id = active_ids[i]
			var def = resolver.call(id)
			var cur := ">" if i == cursor else " "
			var trk := "★" if id == tracked else "●"
			lines.append("%s%s %s — %s" % [cur, trk, def.title, QuestProgress.stage_line(def, quests[id], q)])
	lines.append("-- 已完成 --")
	if done.is_empty():
		lines.append("（無）")
	else:
		lines.append_array(done)
	return lines
```
`refresh` 改傳 tracked + 夾住的游標：

```gdscript
func refresh() -> void:
	var ids := _active_ids()
	_cursor = clampi(_cursor, 0, maxi(0, ids.size() - 1))
	_label.text = "\n".join(summary_lines(
		GameState.quests, GameState.quest_resolver, GameState, GameState.tracked_quest, _cursor))

func _active_ids() -> Array:
	var out: Array = []
	for id in GameState.quests:
		if GameState.is_quest_active(id):
			out.append(id)
	return out
```
`_unhandled_input` 的 Esc 分支改成（加 ↑↓/T）：

```gdscript
	if event.keycode == KEY_ESCAPE:
		close()
	elif event.keycode == KEY_UP:
		_cursor = maxi(0, _cursor - 1)
		refresh()
	elif event.keycode == KEY_DOWN:
		_cursor = mini(_active_ids().size() - 1, _cursor + 1)
		refresh()
	elif event.keycode == KEY_T:
		var ids := _active_ids()
		if _cursor >= 0 and _cursor < ids.size():
			GameState.set_tracked_quest(ids[_cursor])
			refresh()
```

- [ ] **Step 4: import + 跑→通過**（`-gselect=test_quest_log.gd`）

- [ ] **Step 5: Commit**：`git add presentation/ui/quest_log.gd tests/presentation/test_quest_log.gd && git commit -m "feat(quest): QuestLog 游標 + T 挑選追蹤（★ 標記）"`

---

## Task 6: main 接線（toast + tracker）

**Files:** Modify `presentation/world/main.gd`

**Interfaces:** Consumes `QuestToast`、`QuestTracker`、`GameState.quest_event`/`quests_changed`/`retrack`。

- [ ] **Step 1: 改實作** — `presentation/world/main.gd`：
成員區（`var _quest_log: QuestLog` 之後）加：

```gdscript
var _quest_toast: QuestToast
var _quest_tracker: QuestTracker
```
`_ready` 內 `GameState.quests_changed.connect(_on_quests_changed)` 之後加：

```gdscript
	_quest_toast = QuestToast.new()
	add_child(_quest_toast)
	GameState.quest_event.connect(_quest_toast.show_notice)
	_quest_tracker = QuestTracker.new()
	add_child(_quest_tracker)
```
`_on_quests_changed` 改成（追蹤器恆刷新；日誌開著才刷新）：

```gdscript
func _on_quests_changed() -> void:
	_quest_tracker.refresh()
	if _quest_log.is_open():
		_quest_log.refresh()
```
`_on_loaded` 內（`_hud.refresh()` 之前）加：

```gdscript
	GameState.retrack()
	_quest_tracker.refresh()
```

- [ ] **Step 2: import + 全套 + headless boot**：
全套 PASS（main 無單元測試，數量＝各 task 新增測試和）；`godot --headless --path .`（約 3 秒）無 SCRIPT ERROR / Invalid call / nonexistent function。

- [ ] **Step 3: Commit**：`git add presentation/world/main.gd && git commit -m "feat(quest): main 接線 QuestToast(quest_event) + QuestTracker(quests_changed/讀檔 retrack)"`

---

## Self-Review（plan 對 spec 覆蓋）

- Event trigger（quest_event 三處 emit）：Task 1 ✅
- 追蹤狀態 tracked_quest + 自動追蹤 + retrack + set：Task 1 ✅；存檔 v9：Task 2 ✅
- Popup QuestToast（上方置中、排隊）：Task 3 ✅
- 追蹤器 QuestTracker（小地圖下方、tracker_lines）：Task 4 ✅
- J 日誌可挑選追蹤（游標/★/T）：Task 5 ✅
- main 接線（toast/tracker/讀檔 retrack）：Task 6 ✅
- 型別一致：quest_event(text)、tracked_quest:String、tracker_lines(tracked,resolver,q)、summary_lines(...,tracked,cursor)、q 契約（is_quest_active/quests/is_defeated/item_count）全程一致 ✅
