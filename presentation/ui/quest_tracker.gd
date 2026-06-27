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
