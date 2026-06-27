class_name CombatLog
extends Control

# 戰鬥訊息面板：保留最近 MAX_LINES 行。版面比例式（畫面中下、置中橫向），由父層放置。
const MAX_LINES := 8

var _lines: Array[String] = []
var _panel: Panel
var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
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

# Control 直接掛在 CanvasLayer 下時，於 _ready（add_child 後）才設 anchors 不會被重算尺寸
# → 顯式撐成 viewport 大小並隨視窗縮放（解析度無關）。
func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)   # 相等對向 anchors → size 自由、可顯式設、不被覆寫
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size

func push(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_label.text = "\n".join(_lines)

func clear() -> void:
	_lines.clear()
	_label.text = ""
