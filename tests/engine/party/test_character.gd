extends GutTest

func test_defaults_to_ok_alive_conscious():
	var c := Character.new()
	assert_eq(c.condition, Character.Condition.OK)
	assert_true(c.is_alive())
	assert_true(c.is_conscious())

func test_unconscious_is_alive_but_not_conscious():
	var c := Character.new()
	c.condition = Character.Condition.UNCONSCIOUS
	assert_true(c.is_alive())
	assert_false(c.is_conscious())

func test_dead_is_not_alive_not_conscious():
	var c := Character.new()
	c.condition = Character.Condition.DEAD
	assert_false(c.is_alive())
	assert_false(c.is_conscious())

func test_holds_full_stat_block():
	var c := Character.new()
	c.name = "Gerard"
	c.char_class = "Knight"
	c.level = 3
	c.hp = 18
	c.hp_max = 28
	c.sp = 4
	c.sp_max = 8
	c.might = 18
	c.intellect = 7
	c.personality = 9
	c.endurance = 16
	c.speed = 12
	c.accuracy = 14
	c.luck = 10
	assert_eq(c.name, "Gerard")
	assert_eq(c.char_class, "Knight")
	assert_eq(c.level, 3)
	assert_eq(c.hp, 18)
	assert_eq(c.hp_max, 28)
	assert_eq(c.sp, 4)
	assert_eq(c.sp_max, 8)
	assert_eq(c.might, 18)
	assert_eq(c.luck, 10)
