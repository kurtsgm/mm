class_name EnemyPanel
extends Control

# 敵人資訊列（畫面上方置中橫排）：每隻存活怪一塊 plate（編號+名+血條+狀態）。
# 選目標時高亮對應 plate；受擊跳傷害數字。版面比例式，plate 用 size_flags 平均分攤。
const _CIRCLED := ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]

var _row: HBoxContainer
var _plates: Array = []          # 每項：{ "mon": Monster, "panel": Panel, "fill": ColorRect, "label": Label, "status": Label }

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.anchor_left = 0.15
	_row.anchor_right = 0.85
	_row.anchor_top = 0.04
	_row.anchor_bottom = 0.04
	_row.grow_vertical = Control.GROW_DIRECTION_END
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)

static func plate_text(i: int, mon) -> String:
	var sym: String = _CIRCLED[i] if i < _CIRCLED.size() else str(i + 1)
	return "%s%s %d/%d" % [sym, mon.name, maxi(mon.hp, 0), mon.hp_max]

func refresh(living: Array, selected_index: int) -> void:
	for child in _row.get_children():
		_row.remove_child(child); child.free()
	_plates.clear()
	for i in living.size():
		var mon = living[i]
		var panel := Panel.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(0, 52)
		if i == selected_index:
			panel.modulate = Color(1.0, 0.85, 0.4)   # 鎖定高亮
		_row.add_child(panel)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.offset_left = 6; vb.offset_top = 3; vb.offset_right = -6; vb.offset_bottom = -3
		panel.add_child(vb)
		var label := Label.new()
		label.text = plate_text(i, mon)
		label.add_theme_font_size_override("font_size", 14)
		vb.add_child(label)
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(0.1, 0.1, 0.1)
		bar_bg.custom_minimum_size = Vector2(0, 8)
		vb.add_child(bar_bg)
		var fill := ColorRect.new()
		fill.color = Color(0.8, 0.2, 0.2)
		fill.anchor_left = 0.0; fill.anchor_top = 0.0
		fill.anchor_right = PartyMemberCard.bar_ratio(mon.hp, mon.hp_max); fill.anchor_bottom = 1.0
		bar_bg.add_child(fill)
		var status := Label.new()
		status.text = _status_line(mon)
		status.add_theme_font_size_override("font_size", 11)
		status.add_theme_color_override("font_color", Color(0.8, 0.6, 0.9))
		vb.add_child(status)
		_plates.append({ "mon": mon, "panel": panel, "fill": fill, "label": label, "status": status })

func flash_damage(monster, amount: int) -> void:
	var plate = _find_plate(monster)
	if plate == null:
		return
	var num := Label.new()
	num.text = "-%d" % amount
	num.add_theme_font_size_override("font_size", 22)
	num.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	(plate["panel"] as Control).add_child(num)
	num.position = Vector2(0, -6)
	var tw := create_tween()
	tw.tween_property(num, "position:y", -34.0, 0.6)
	tw.parallel().tween_property(num, "modulate:a", 0.0, 0.6)
	tw.tween_callback(num.queue_free)

func _find_plate(monster):
	for p in _plates:
		if p["mon"] == monster:
			return p
	return null

func _status_line(mon) -> String:
	var parts: Array[String] = []
	for s in mon.statuses:
		parts.append(PartyMemberCard.status_text(s))
	return "  ".join(parts)
