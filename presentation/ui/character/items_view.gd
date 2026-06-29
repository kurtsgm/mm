class_name CharacterItemsView
extends Control

# 道具分頁的雙欄視覺：左「裝備」(3 槽) / 右「背包」(可捲動清單)。
# 純呈現：輸入 rows（CharacterItemsTab.rows，含 stat/category）+ active_index，重建兩欄、標出作用列。
# 版面比例式（欄寬走 size_flags ratio），不寫死像素。色標用安全中文單字避免缺字破圖。

var _equip_box: VBoxContainer
var _bag_box: VBoxContainer
var _equip_rows: Array = []
var _bag_rows: Array = []
var _active_index: int = 0
var _equip_n: int = 0
var _has_empty: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	_equip_box = _make_column("裝 備", 0.42, root)
	_bag_box = _make_column("背 包", 0.58, root)

# 一欄＝框起的 Panel + 標題 + 內容 VBox；回傳內容 VBox 供填列。
func _make_column(title: String, ratio: float, parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", _column_stylebox())
	parent.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var head := Label.new()
	head.text = title
	head.add_theme_color_override("font_color", PanelSkin.SECTION)
	head.add_theme_font_size_override("font_size", PanelSkin.FONT_HEADER)
	head.add_theme_constant_override("outline_size", PanelSkin.OUTLINE_SIZE)
	head.add_theme_color_override("font_outline_color", PanelSkin.OUTLINE_COLOR)
	col.add_child(head)

	var sep := HSeparator.new()
	col.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	scroll.add_child(body)
	return body

func refresh(rows: Array, active_index: int) -> void:
	_active_index = active_index
	_equip_n = 0
	for r in rows:
		if String(r.get("kind", "")) == "equip":
			_equip_n += 1
	_clear(_equip_box, _equip_rows)
	_clear(_bag_box, _bag_rows)
	_has_empty = false
	for i in rows.size():
		var r: Dictionary = rows[i]
		var active := i == active_index
		if String(r.get("kind", "")) == "equip":
			_equip_box.add_child(_equip_row(r, active))
			_equip_rows.append(r)
		else:
			_bag_box.add_child(_bag_row(r, active))
			_bag_rows.append(r)
	if _bag_rows.is_empty():
		var empty := Label.new()
		empty.text = "（空）"
		empty.add_theme_color_override("font_color", PanelSkin.TEXT)
		empty.add_theme_font_size_override("font_size", PanelSkin.FONT_BODY)
		_bag_box.add_child(empty)
		_has_empty = true

func equip_count() -> int:
	return _equip_rows.size()

func bag_count() -> int:
	return _bag_rows.size()

func active_index() -> int:
	return _active_index

func active_in_bag() -> bool:
	return _active_index >= _equip_n

func has_empty_placeholder() -> bool:
	return _has_empty

# 裝備列：色標 | 槽名 | 道具名(撐開) | 數值
func _equip_row(r: Dictionary, active: bool) -> Control:
	var cat := int(r.get("slot", 0))   # 槽 enum 與分類 enum 同值
	var hb := _row_container(active)
	hb.add_child(PanelSkin.make_chip(category_label(cat), category_color(cat)))
	hb.add_child(_slot_label_node(_slot_text(cat)))
	hb.add_child(_grow_label(_equip_name(r), PanelSkin.TEXT))
	hb.add_child(_fixed_label(String(r.get("stat", "")), PanelSkin.TITLE))
	return _wrap(hb, active)

# 背包列：色標 | 名稱(撐開) | ×數量
func _bag_row(r: Dictionary, active: bool) -> Control:
	var cat := int(r.get("category", ItemDef.Category.CONSUMABLE))
	var hb := _row_container(active)
	hb.add_child(PanelSkin.make_chip(category_label(cat), category_color(cat)))
	hb.add_child(_grow_label(String(r.get("name", "")), PanelSkin.TEXT))
	hb.add_child(_fixed_label("×%d" % int(r.get("count", 0)), PanelSkin.TITLE))
	return _wrap(hb, active)

func _row_container(_active: bool) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return hb

# 包一層 PanelContainer 以便整列反白（作用列）。
func _wrap(inner: Control, active: bool) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", PanelSkin.row_hilite_stylebox() if active else StyleBoxEmpty.new())
	pc.add_child(inner)
	return pc

func _equip_name(r: Dictionary) -> String:
	var nm := String(r.get("name", "-"))
	return "—" if nm == "-" else nm

func _slot_label_node(text: String) -> Label:
	var l := _fixed_label(text, PanelSkin.SECTION)
	l.custom_minimum_size = Vector2(72, 0)
	return l

func _grow_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", PanelSkin.FONT_BODY)
	l.add_theme_constant_override("outline_size", PanelSkin.OUTLINE_SIZE)
	l.add_theme_color_override("font_outline_color", PanelSkin.OUTLINE_COLOR)
	return l

func _fixed_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", PanelSkin.FONT_BODY)
	l.add_theme_constant_override("outline_size", PanelSkin.OUTLINE_SIZE)
	l.add_theme_color_override("font_outline_color", PanelSkin.OUTLINE_COLOR)
	return l

func _clear(box: VBoxContainer, tracked: Array) -> void:
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	tracked.clear()

func _slot_text(slot: int) -> String:
	match slot:
		Equipment.Slot.WEAPON:
			return "武器"
		Equipment.Slot.ARMOR:
			return "防具"
		Equipment.Slot.ACCESSORY:
			return "飾品"
	return "?"

func _column_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.80, 0.71, 0.52, 0.28)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = PanelSkin.FRAME
	sb.set_content_margin_all(10)
	return sb

static func category_label(category: int) -> String:
	match category:
		ItemDef.Category.WEAPON:
			return "武"
		ItemDef.Category.ARMOR:
			return "甲"
		ItemDef.Category.ACCESSORY:
			return "飾"
		ItemDef.Category.CONSUMABLE:
			return "用"
	return "?"

static func category_color(category: int) -> Color:
	match category:
		ItemDef.Category.WEAPON:
			return PanelSkin.HP_FILL
		ItemDef.Category.ARMOR:
			return PanelSkin.SP_FILL
		ItemDef.Category.ACCESSORY:
			return PanelSkin.XP_FILL
		ItemDef.Category.CONSUMABLE:
			return PanelSkin.USE_FILL
	return PanelSkin.FRAME
