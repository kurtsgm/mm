class_name QuestLog
extends CanvasLayer
# J 鍵開關的任務日誌面板。進行中顯示標題＋當前階段進度；已完成另列。
# 版面用 anchor 比例（解析度無關）。文字邏輯走純 summary_lines（可測）。

signal closed

var _panel: Panel
var _label: Label
var _cursor: int = 0

func is_open() -> bool:
	return visible

func open() -> void:
	visible = true
	set_process_unhandled_input(true)
	refresh()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	closed.emit()

func _ready() -> void:
	layer = 10
	visible = false
	_panel = Panel.new()
	_panel.anchor_left = 0.2
	_panel.anchor_right = 0.8
	_panel.anchor_top = 0.15
	_panel.anchor_bottom = 0.85
	add_child(_panel)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 16
	_label.offset_top = 12
	_label.offset_right = -16
	_label.offset_bottom = -12
	_label.add_theme_font_size_override("font_size", 18)
	_panel.add_child(_label)
	set_process_unhandled_input(false)

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

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# 只自處理 Esc/↑↓/T；J 的開/關交給 main._toggle_menu（沿用 Save/Inventory/Spell 選單慣例）。
	# 若這裡也吃 J：child 先收事件→close()，事件未被消費→main 再收 J→看到已關→又重開（無法用 J 關閉）。
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
