extends GutTest

func _char(cls := "Knight", hp := 28, hp_max := 28, sp := 8, sp_max := 8) -> Character:
	var c := Character.new()
	c.name = "Hero"
	c.char_class = cls
	c.level = 3
	c.hp = hp
	c.hp_max = hp_max
	c.sp = sp
	c.sp_max = sp_max
	c.condition = Character.Condition.OK
	return c

func _card(c: Character) -> PartyMemberCard:
	var card := PartyMemberCard.new()
	add_child_autofree(card)
	card.setup(c)
	return card

func test_hp_label_shows_tag_and_values():
	assert_eq(_card(_char("Knight", 24, 28))._hp_label.text, "HP 24/28")

# 治療術/喝藥水後不需手動 refresh：角色 HP/MP 一變，卡片即時跟著更新。
func test_card_auto_refreshes_when_hp_changes():
	var c := _char("Cleric", 10, 28)
	var card := _card(c)
	c.hp = 25                               # 模擬治療術回血（直接改 hp，不呼叫 card.refresh）
	assert_eq(card._hp_label.text, "HP 25/28")

func test_card_auto_refreshes_when_sp_changes():
	var c := _char("Cleric", 28, 28, 4, 8)
	var card := _card(c)
	c.sp -= 2                               # 模擬施法扣 MP
	assert_eq(card._mp_label.text, "MP 2/8")

func test_mp_label_uses_mp_tag_from_sp_fields():
	assert_eq(_card(_char("Cleric", 28, 28, 4, 8))._mp_label.text, "MP 4/8")

func test_bar_ratio_quarter():
	assert_almost_eq(PartyMemberCard.bar_ratio(7, 28), 0.25, 0.0001)

func test_bar_ratio_zero_max_is_zero():
	assert_eq(PartyMemberCard.bar_ratio(5, 0), 0.0)

func test_bar_ratio_clamped_to_one():
	assert_eq(PartyMemberCard.bar_ratio(40, 20), 1.0)

func test_visual_ok_when_healthy():
	assert_eq(_card(_char("Knight", 28, 28)).current_visual(), PartyMemberCard.FaceVisual.OK)

func test_visual_hurt_when_low_hp():
	assert_eq(_card(_char("Knight", 7, 28)).current_visual(), PartyMemberCard.FaceVisual.HURT)

func test_visual_unconscious():
	var c := _char("Knight", 0, 28)
	c.condition = Character.Condition.UNCONSCIOUS
	assert_eq(_card(c).current_visual(), PartyMemberCard.FaceVisual.UNCONSCIOUS)

func test_visual_dead():
	var c := _char("Knight", 0, 28)
	c.condition = Character.Condition.DEAD
	assert_eq(_card(c).current_visual(), PartyMemberCard.FaceVisual.DEAD)

func test_flash_hit_overrides_to_hit_visual():
	var card := _card(_char("Knight", 28, 28))
	card.flash_hit()
	assert_true(card.is_hit_active())
	assert_eq(card.current_visual(), PartyMemberCard.FaceVisual.HIT)

func test_status_text_buff_and_debuff():
	assert_eq(PartyMemberCard.status_text(StatusEffect.new(StatusEffect.Stat.ATTACK, 5, 2)), "↑ATK")
	assert_eq(PartyMemberCard.status_text(StatusEffect.new(StatusEffect.Stat.ARMOR, -3, 2)), "↓DEF")
	assert_eq(PartyMemberCard.status_text(StatusEffect.new(StatusEffect.Stat.ACCURACY, 4, 2)), "↑ACC")

func test_buff_row_renders_one_chip_per_status():
	var c := _char("Sorcerer")
	c.statuses.append(StatusEffect.new(StatusEffect.Stat.ATTACK, 5, 2))
	c.statuses.append(StatusEffect.new(StatusEffect.Stat.ARMOR, -3, 2))
	var card := _card(c)
	assert_eq(card._buff_row.get_child_count(), 2)
	assert_eq((card._buff_row.get_child(0) as Label).text, "↑ATK")

func test_character_accessor_returns_bound_character():
	var c := _char("Knight")
	assert_eq(_card(c).character(), c)

func test_real_portrait_shows_texture_and_hides_glyph():
	var c := _char("Knight")
	c.name = "Gerard"                      # PortraitCatalog 有對應貼圖
	var card := _card(c)
	assert_true(card._portrait_tex.visible)
	assert_false(card._portrait_glyph.visible)
	assert_not_null(card._portrait_tex.texture)

func test_placeholder_when_no_portrait():
	var c := _char("Knight")
	c.name = "Nobody"                      # 無對應貼圖 → 回 placeholder
	var card := _card(c)
	assert_false(card._portrait_tex.visible)
	assert_true(card._portrait_glyph.visible)
