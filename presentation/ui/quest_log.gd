class_name QuestLog
extends CanvasLayer
# J 鍵開關的任務日誌面板。進行中顯示標題＋當前階段進度；已完成另列。
# 版面用 anchor 比例（解析度無關）。文字邏輯走純 summary_lines（可測）。

signal closed

var _panel: Panel
var _label: Label

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
	_label.text = "\n".join(summary_lines(
		GameState.quests, GameState.quest_resolver, Callable(GameState.inventory, "count_of")))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_J:
		close()

static func summary_lines(quests: Dictionary, resolver: Callable, have_count: Callable) -> Array:
	var active: Array[String] = []
	var done: Array[String] = []
	for id in quests:
		var def = resolver.call(id) if resolver.is_valid() else null
		if def == null:
			continue
		var state: Dictionary = quests[id]
		if String(state.get("status", "")) == "done":
			done.append("✓ %s" % def.title)
		else:
			active.append("● %s — %s" % [def.title, QuestProgress.stage_line(def, state, have_count)])
	var lines: Array[String] = ["== 任務日誌 ==  [J/Esc] 關"]
	lines.append("-- 進行中 --")
	if active.is_empty():
		lines.append("（無）")
	else:
		lines.append_array(active)
	lines.append("-- 已完成 --")
	if done.is_empty():
		lines.append("（無）")
	else:
		lines.append_array(done)
	return lines
