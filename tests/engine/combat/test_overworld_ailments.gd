extends GutTest

func _char(hp: int) -> Character:
	var c := Character.new()
	c.name = "英雄"; c.hp = hp; c.hp_max = 30; c.condition = Character.Condition.OK
	return c

func test_tick_poison_damages_and_decays():
	var c := _char(20)
	c.statuses.append(StatusCatalog.poison(4, 2))
	var ev := OverworldAilments.tick_poison([c])
	assert_eq(c.hp, 16)
	assert_eq(c.statuses[0].remaining, 1)
	assert_false(ev.is_empty())

func test_tick_poison_floors_at_one_not_kill():
	var c := _char(2)
	c.statuses.append(StatusCatalog.poison(9, 3))
	OverworldAilments.tick_poison([c])
	assert_eq(c.hp, 1)                                  # 不致死
	assert_eq(c.condition, Character.Condition.OK)

func test_tick_poison_expires_at_zero_remaining():
	var c := _char(20)
	c.statuses.append(StatusCatalog.poison(2, 1))
	OverworldAilments.tick_poison([c])
	assert_eq(c.statuses.size(), 0)

func test_tick_ignores_non_poison():
	var c := _char(20)
	c.statuses.append(StatusCatalog.burn(4, 3))   # 燒不外滲
	OverworldAilments.tick_poison([c])
	assert_eq(c.hp, 20)
