extends GutTest

func _char() -> Character:
	var c := Character.new()
	c.name = "Hero"; c.level = 1; c.hp = 10; c.hp_max = 10; c.sp = 5; c.sp_max = 5
	c.char_class = "Knight"; c.condition = Character.Condition.OK
	return c

func test_active_flag_toggles():
	var card := PartyMemberCard.new()
	add_child_autofree(card)
	card.setup(_char())
	assert_false(card.is_active())
	card.set_active(true)
	assert_true(card.is_active())

func test_defending_flag_toggles():
	var card := PartyMemberCard.new()
	add_child_autofree(card)
	card.setup(_char())
	card.set_defending(true)
	assert_true(card.is_defending())
	card.set_defending(false)
	assert_false(card.is_defending())
