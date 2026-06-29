class_name PartyRail
extends VBoxContainer

# 左側隊員直欄：每名隊員一列（頭像＋名字＋職業簡稱＋迷你 HP）。目前隊員整列高亮。
# 純顯示，切換由面板輸入驅動（1-6/Tab）；refresh 重建。

const _CLASS_ABBR := {
	"Knight": "騎", "Paladin": "聖", "Archer": "弓",
	"Cleric": "牧", "Sorcerer": "法", "Robber": "盜",
}

var _selected: int = 0
var _rows: int = 0

func row_count() -> int:
	return _rows

func selected() -> int:
	return _selected

func refresh(members: Array, selected_idx: int) -> void:
	_selected = selected_idx
	_rows = members.size()
	for c in get_children():
		c.queue_free()
		remove_child(c)
	add_theme_constant_override("separation", 6)
	for i in members.size():
		add_child(_build_row(members[i], i, i == selected_idx))

func _build_row(member: Character, index: int, is_sel: bool) -> Control:
	var row := PanelContainer.new()
	if is_sel:
		row.add_theme_stylebox_override("panel", PanelSkin.row_hilite_stylebox())
	else:
		# 非選取列：透明底，避免 PanelContainer 預設深色面板壓在乾淨羊皮上很突兀。
		row.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	row.add_child(hb)

	# 頭像（含 1-N 編號）
	var av := _portrait(member, index)
	hb.add_child(av)

	# 名字 + 職業 + 迷你 HP
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var nm := Label.new()
	nm.text = "%s %s" % [member.name, _abbr(member.char_class)]
	nm.add_theme_color_override("font_color", PanelSkin.TITLE)
	nm.add_theme_font_size_override("font_size", 27)
	nm.add_theme_constant_override("outline_size", PanelSkin.OUTLINE_SIZE)
	nm.add_theme_color_override("font_outline_color", PanelSkin.OUTLINE_COLOR)
	col.add_child(nm)
	var bar := PanelSkin.make_bar(PanelSkin.HP_FILL)
	bar["root"].custom_minimum_size = Vector2(0, 12)
	PanelSkin.set_ratio(bar, PartyMemberCard.bar_ratio(member.hp, member.hp_max))
	col.add_child(bar["root"])
	return row

func _portrait(member: Character, index: int) -> Control:
	# 深棕有框槽位：缺圖的隊員也看得到框（不會消失在淺色閱讀底上）。
	var box := Panel.new()
	box.custom_minimum_size = Vector2(84, 84)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.24, 0.15)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = PanelSkin.FRAME
	box.add_theme_stylebox_override("panel", sb)
	var tex := PortraitCatalog.texture_for(member)
	if tex != null:
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = tex
		box.add_child(tr)
	# 編號角標（淺字深描邊，無論底圖深淺都讀得到）
	var num := Label.new()
	num.text = str(index + 1)
	num.add_theme_color_override("font_color", Color(0.96, 0.90, 0.74))
	num.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.05))
	num.add_theme_constant_override("outline_size", 4)
	num.add_theme_font_size_override("font_size", 18)
	num.position = Vector2(5, 2)
	box.add_child(num)
	return box

func _abbr(cls: String) -> String:
	return _CLASS_ABBR.get(cls, "")
