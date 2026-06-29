class_name PanelSkin
extends Object

# 羊皮紙古卷皮的共用工具：顏色、StyleBox、比例條、狀態 chip。
# 程式化近似（v1）；真 9-patch 貼圖屬後續，可只改本檔不動呼叫端。

const PARCHMENT := Color(0.86, 0.78, 0.60)
const FRAME := Color(0.54, 0.42, 0.23)
const GOLD := Color(0.72, 0.57, 0.25)
const TEXT := Color(0.23, 0.16, 0.09)
const TITLE := Color(0.35, 0.23, 0.09)
const SECTION := Color(0.48, 0.35, 0.16)
const HP_FILL := Color(0.75, 0.22, 0.16)
const XP_FILL := Color(0.79, 0.63, 0.29)
const BAR_BG := Color(0.42, 0.35, 0.22)
const HILITE := Color(0.48, 0.35, 0.16, 0.30)

static func frame_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.set_border_width_all(5)
	sb.border_color = FRAME
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	return sb

static func tab_stylebox(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SECTION if active else Color(0.48, 0.35, 0.16, 0.16)
	sb.set_corner_radius_all(5)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.set_content_margin_all(6)
	if active:
		sb.border_width_bottom = 2
		sb.border_color = GOLD
	return sb

static func row_hilite_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HILITE
	sb.set_corner_radius_all(5)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = GOLD
	return sb

static func make_bar(fill_color: Color) -> Dictionary:
	var bg := ColorRect.new()
	bg.color = BAR_BG
	bg.custom_minimum_size = Vector2(0, 12)
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	bg.add_child(fill)
	return {"root": bg, "fill": fill}

static func set_ratio(bar: Dictionary, ratio: float) -> void:
	bar["fill"].anchor_right = clampf(ratio, 0.0, 1.0)

static func make_chip(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl
