extends GutTest

func _char(hp: int, hp_max: int, cond := Character.Condition.OK) -> Character:
	var c := Character.new()
	c.hp = hp
	c.hp_max = hp_max
	c.condition = cond
	return c

func test_dead_takes_priority_over_hp():
	assert_eq(PortraitState.for_character(_char(0, 28, Character.Condition.DEAD)), PortraitState.Face.DEAD)

func test_unconscious_when_ko():
	assert_eq(PortraitState.for_character(_char(0, 28, Character.Condition.UNCONSCIOUS)), PortraitState.Face.UNCONSCIOUS)

func test_ok_when_healthy():
	assert_eq(PortraitState.for_character(_char(28, 28)), PortraitState.Face.OK)

func test_hurt_at_or_below_quarter():
	# 28 * 0.25 = 7 → hp 7 為邊界，算重傷
	assert_eq(PortraitState.for_character(_char(7, 28)), PortraitState.Face.HURT)
	assert_eq(PortraitState.for_character(_char(8, 28)), PortraitState.Face.OK)

func test_zero_max_is_ok_not_hurt():
	assert_eq(PortraitState.for_character(_char(0, 0)), PortraitState.Face.OK)
