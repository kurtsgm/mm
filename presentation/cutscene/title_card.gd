class_name TitleCard
extends Control
# 章節標題卡：黑底、標題＋副標置中。版面比例式（占滿全螢幕），字級固定。

var _bg: ColorRect
var _title_label: Label
var _subtitle_label: Label

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 1)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	vb.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 28)
	_subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	vb.add_child(_subtitle_label)

func set_content(title: String, subtitle: String) -> void:
	if _title_label == null:
		# 尚未 _ready → 忽略此次設值（進 tree 後 _ready 才建節點）。
		return
	_title_label.text = title
	_subtitle_label.text = subtitle
	_subtitle_label.visible = subtitle != ""
