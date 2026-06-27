class_name CombatLog
extends Control

# 戰鬥訊息面板：保留最近 MAX_LINES 行。版面比例式（畫面中下、置中橫向），由父層放置。
const MAX_LINES := 8

var _lines: Array[String] = []
var _panel: Panel
var _label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = Panel.new()
	_panel.anchor_left = 0.20
	_panel.anchor_right = 0.80
	_panel.anchor_top = 0.55
	_panel.anchor_bottom = 0.74
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 10; _label.offset_top = 6
	_label.offset_right = -10; _label.offset_bottom = -6
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 15)
	_panel.add_child(_label)

func push(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_label.text = "\n".join(_lines)

func clear() -> void:
	_lines.clear()
	_label.text = ""
