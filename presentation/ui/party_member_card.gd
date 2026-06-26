class_name PartyMemberCard
extends VBoxContainer
# 單一隊友卡：placeholder 頭像（依狀態換臉）＋ HP/MP 條 ＋ buff/debuff 列。
# 全程式建構、無美術。卡片以 SIZE_EXPAND_FILL 在 PartyPanel 內平均分攤寬度，
# 內部頭像/血條以「撐滿 + anchor 比例」呈現 → 隨視窗縮放、解析度無關（不寫死像素寬）。

const HIT_MS := 400                       # 受擊閃臉持續毫秒
const _PORTRAIT_MIN_HEIGHT := 72          # 頭像最小高（寬度隨卡片平攤而擴張）
const _BAR_HEIGHT := 18                    # HP/MP 條高

enum FaceVisual { OK, HURT, HIT, UNCONSCIOUS, DEAD }

const _GLYPH := {
	FaceVisual.OK: ":)",
	FaceVisual.HURT: ":(",
	FaceVisual.HIT: "><",
	FaceVisual.UNCONSCIOUS: "x_x",
	FaceVisual.DEAD: "✝",
}
const _TINT := {
	FaceVisual.OK: Color(1, 1, 1),
	FaceVisual.HURT: Color(0.85, 0.55, 0.55),
	FaceVisual.HIT: Color(1.0, 0.45, 0.45),
	FaceVisual.UNCONSCIOUS: Color(0.55, 0.55, 0.55),
	FaceVisual.DEAD: Color(0.3, 0.3, 0.3),
}

var _character: Character
var _hit_until_msec: int = 0
var _portrait_texture: Texture2D            # 真頭像（無則為 null → 用色塊 placeholder）

var _portrait: ColorRect
var _portrait_tex: TextureRect
var _portrait_glyph: Label
var _name_label: Label
var _hp_fill: ColorRect
var _hp_label: Label
var _mp_fill: ColorRect
var _mp_label: Label
var _buff_row: HBoxContainer

func setup(character: Character) -> void:
	_character = character
	_portrait_texture = PortraitCatalog.texture_for(character)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL   # 在 PartyPanel 內平均分攤寬度
	add_theme_constant_override("separation", 3)
	_build()
	refresh()

func character() -> Character:
	return _character

func _build() -> void:
	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(0, _PORTRAIT_MIN_HEIGHT)
	_portrait.size_flags_horizontal = Control.SIZE_FILL   # 撐滿卡片寬
	add_child(_portrait)
	# 真頭像：疊滿色塊、保持比例填滿並裁切（小格也能看清臉）
	_portrait_tex = TextureRect.new()
	_portrait_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_tex.texture = _portrait_texture
	_portrait.add_child(_portrait_tex)
	_portrait_glyph = Label.new()
	_portrait_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_glyph.add_theme_font_size_override("font_size", 32)
	_portrait.add_child(_portrait_glyph)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

	_hp_fill = _make_bar(Color(0.8, 0.2, 0.2))
	_hp_label = _bar_label(_hp_fill)
	_mp_fill = _make_bar(Color(0.25, 0.45, 0.9))
	_mp_label = _bar_label(_mp_fill)

	_buff_row = HBoxContainer.new()
	_buff_row.add_theme_constant_override("separation", 3)
	add_child(_buff_row)

func _make_bar(fill_color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1)
	bg.custom_minimum_size = Vector2(0, _BAR_HEIGHT)   # 寬隨卡片擴張
	add_child(bg)
	var fill := ColorRect.new()
	fill.color = fill_color
	# 以 anchor_right 表示比例 → 填色寬隨 bar（卡片）寬自動縮放，解析度無關
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 0
	fill.offset_top = 0
	fill.offset_right = 0
	fill.offset_bottom = 0
	bg.add_child(fill)
	return fill

func _bar_label(fill: ColorRect) -> Label:
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	(fill.get_parent() as Control).add_child(lbl)   # 疊在 bar 背景上
	return lbl

func refresh() -> void:
	if _character == null:
		return
	_name_label.text = "%s L%d" % [_character.name, _character.level]
	_apply_bar(_hp_fill, _hp_label, "HP", _character.hp, _character.hp_max)
	_apply_bar(_mp_fill, _mp_label, "MP", _character.sp, _character.sp_max)
	_apply_face()
	_apply_buffs()

func _apply_bar(fill: ColorRect, label: Label, tag: String, value: int, max_value: int) -> void:
	fill.anchor_right = bar_ratio(value, max_value)   # 填色寬 = 比例 × bar 寬
	label.text = "%s %d/%d" % [tag, value, max_value]

static func bar_ratio(value: int, max_value: int) -> float:
	if max_value <= 0:
		return 0.0
	return clampf(float(value) / float(max_value), 0.0, 1.0)

# --- 頭像換臉 ---

func flash_hit() -> void:
	_hit_until_msec = Time.get_ticks_msec() + HIT_MS
	set_process(true)
	_apply_face()

func is_hit_active() -> bool:
	return Time.get_ticks_msec() < _hit_until_msec

func current_visual() -> int:
	if is_hit_active():
		return FaceVisual.HIT
	match PortraitState.for_character(_character):
		PortraitState.Face.DEAD:
			return FaceVisual.DEAD
		PortraitState.Face.UNCONSCIOUS:
			return FaceVisual.UNCONSCIOUS
		PortraitState.Face.HURT:
			return FaceVisual.HURT
		_:
			return FaceVisual.OK

func _apply_face() -> void:
	var v := current_visual()
	if _portrait_texture != null:
		# 真頭像：顯示貼圖、狀態以 modulate 上色（受擊紅閃/暈倒灰/死亡暗）；字符隱藏。
		_portrait_tex.visible = true
		_portrait_glyph.visible = false
		_portrait.modulate = Color(1, 1, 1)
		_portrait_tex.modulate = _TINT[v]
	else:
		# placeholder：職業色塊 + 表情字符，整體以 modulate 上狀態色。
		_portrait_tex.visible = false
		_portrait_glyph.visible = true
		_portrait_glyph.text = _GLYPH[v]
		_portrait.color = _class_color(_character.char_class)
		_portrait.modulate = _TINT[v]

func _process(_delta: float) -> void:
	if not is_hit_active():
		set_process(false)
		_apply_face()

func _on_self_damaged(_amount: int) -> void:
	flash_hit()

# --- buff/debuff ---

func _apply_buffs() -> void:
	for child in _buff_row.get_children():
		_buff_row.remove_child(child)
		child.free()
	for s in _character.statuses:
		var chip := Label.new()
		chip.add_theme_font_size_override("font_size", 12)
		chip.text = status_text(s)
		chip.add_theme_color_override("font_color", status_color(s))
		_buff_row.add_child(chip)

static func status_text(s: StatusEffect) -> String:
	var arrow := "↑" if s.amount > 0 else "↓"
	return arrow + _stat_abbrev(s.stat)

static func status_color(s: StatusEffect) -> Color:
	return Color(0.4, 0.9, 0.4) if s.amount > 0 else Color(0.95, 0.4, 0.4)

static func _stat_abbrev(stat: int) -> String:
	match stat:
		StatusEffect.Stat.ATTACK:
			return "ATK"
		StatusEffect.Stat.ARMOR:
			return "DEF"
		StatusEffect.Stat.ACCURACY:
			return "ACC"
		_:
			return "?"

static func _class_color(char_class: String) -> Color:
	match char_class:
		"Knight":
			return Color(0.55, 0.35, 0.30)
		"Paladin":
			return Color(0.85, 0.78, 0.45)
		"Archer":
			return Color(0.35, 0.6, 0.35)
		"Cleric":
			return Color(0.8, 0.8, 0.85)
		"Sorcerer":
			return Color(0.45, 0.4, 0.75)
		"Robber":
			return Color(0.4, 0.4, 0.45)
		_:
			return Color(0.5, 0.5, 0.5)
