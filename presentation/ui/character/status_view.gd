class_name CharacterStatusView
extends VBoxContainer

# Status 分頁的 widget 呈現：大頭像 + 名字/職業/等級 + HP 條 + 經驗條 + 七圍格 + 衍生 + 狀態 chip。
# 資料取自 CharacterStatusTab.fields()；每次 refresh 全部重建（資料量小、簡單可靠）。

var _name_label: Label
var _hp_bar: Dictionary
var _sp_bar: Dictionary
var _xp_bar: Dictionary
var _chip_count: int = 0

func name_text() -> String:
	return _name_label.text if _name_label != null else ""

func hp_ratio() -> float:
	return _hp_bar["fill"].anchor_right if not _hp_bar.is_empty() else 0.0

func sp_ratio() -> float:
	return _sp_bar["fill"].anchor_right if not _sp_bar.is_empty() else 0.0

func has_sp_bar() -> bool:
	return not _sp_bar.is_empty()

func xp_ratio() -> float:
	return _xp_bar["fill"].anchor_right if not _xp_bar.is_empty() else 0.0

func chip_count() -> int:
	return _chip_count

func refresh(member: Character) -> void:
	for c in get_children():
		c.queue_free()
		remove_child(c)
	add_theme_constant_override("separation", 22)
	_hp_bar = {}
	_sp_bar = {}
	_xp_bar = {}
	if member == null:
		_name_label = null
		_chip_count = 0
		return
	var f := CharacterStatusTab.fields(member)

	# --- 頭部：頭像 + 名字/職業·等級 + HP + 經驗 ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	add_child(head)
	head.add_child(_big_portrait(member))

	var ht := VBoxContainer.new()
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.add_theme_constant_override("separation", 5)
	head.add_child(ht)
	_name_label = _mk(String(f["name"]), PanelSkin.TITLE, 46)
	ht.add_child(_name_label)
	ht.add_child(_mk("%s　Lv %d" % [String(f["class_label"]), int(f["level"])], PanelSkin.SECTION, 28))
	ht.add_child(_labeled_bar("HP %d/%d" % [int(f["hp"]), int(f["hp_max"])], PanelSkin.HP_FILL,
		PartyMemberCard.bar_ratio(int(f["hp"]), int(f["hp_max"])), "_hp_bar"))
	# SP 條只對有 SP 的施法者顯示（不施法的職業 sp_max=0，不顯示空條）。
	if int(f["sp_max"]) > 0:
		ht.add_child(_labeled_bar("SP %d/%d" % [int(f["sp"]), int(f["sp_max"])], PanelSkin.SP_FILL,
			PartyMemberCard.bar_ratio(int(f["sp"]), int(f["sp_max"])), "_sp_bar"))
	ht.add_child(_labeled_bar("經驗 %d/%d（距下一級 %d）" % [int(f["xp"]), int(f["xp_need"]), int(f["xp_to_next"])],
		PanelSkin.XP_FILL, PartyMemberCard.bar_ratio(int(f["xp"]), int(f["xp_need"])), "_xp_bar"))

	# --- 七圍格（3 欄）---
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 44)
	grid.add_theme_constant_override("v_separation", 14)
	add_child(grid)
	var s: Dictionary = f["stats"]
	# SP 已移到頭部血條區（施法者才有條），故七圍格不再列 SP，避免重複。
	for pair in [["力量", s["might"]], ["智力", s["intellect"]], ["人格", s["personality"]],
				 ["耐力", s["endurance"]], ["速度", s["speed"]], ["精準", s["accuracy"]],
				 ["幸運", s["luck"]], ["狀態", String(f["condition_label"])]]:
		grid.add_child(_mk("%s %s" % [String(pair[0]), str(pair[1])], PanelSkin.TEXT, 30))

	# --- 衍生 ---
	add_child(_mk("攻擊 %d　　防禦 %d　　命中 %d" % [int(f["attack"]), int(f["armor"]), int(f["accuracy_eff"])], Color(0.49, 0.13, 0.10), 30))

	# --- 狀態異常 chip ---
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	add_child(chips)
	chips.add_child(_mk("狀態異常：", PanelSkin.SECTION, 24))
	_chip_count = (f["statuses"] as Array).size()
	if _chip_count == 0:
		chips.add_child(_mk("無", PanelSkin.TEXT, 24))
	else:
		for st in f["statuses"]:
			chips.add_child(PanelSkin.make_chip(String(st["label"]), st["color"]))

func _mk(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", PanelSkin.OUTLINE_SIZE)
	l.add_theme_color_override("font_outline_color", PanelSkin.OUTLINE_COLOR)
	return l

func _labeled_bar(text: String, fill: Color, ratio: float, which: String) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	wrap.add_child(_mk(text, PanelSkin.TEXT, 22))
	var bar := PanelSkin.make_bar(fill)
	bar["root"].custom_minimum_size = Vector2(0, 16)
	PanelSkin.set_ratio(bar, ratio)
	# 血條不佔滿整列：條占約一半寬、右側留白，避免在大面板上被拉太長。
	var barline := HBoxContainer.new()
	bar["root"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar["root"].size_flags_stretch_ratio = 0.5
	barline.add_child(bar["root"])
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.5
	barline.add_child(spacer)
	wrap.add_child(barline)
	match which:
		"_hp_bar":
			_hp_bar = bar
		"_sp_bar":
			_sp_bar = bar
		_:
			_xp_bar = bar
	return wrap

func _big_portrait(member: Character) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(248, 248)
	var tex := PortraitCatalog.texture_for(member)
	if tex != null:
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = tex
		box.add_child(tr)
	else:
		var ph := ColorRect.new()
		ph.set_anchors_preset(Control.PRESET_FULL_RECT)
		ph.color = Color(0.30, 0.24, 0.15)
		box.add_child(ph)
		var g := Label.new()
		g.set_anchors_preset(Control.PRESET_FULL_RECT)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.text = "肖像"
		g.add_theme_color_override("font_color", Color(0.85, 0.78, 0.60))
		box.add_child(g)
	return box
