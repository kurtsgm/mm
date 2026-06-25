extends GutTest

func test_defaults():
	var d := MonsterDef.new()
	assert_eq(d.display_name, "")
	assert_eq(d.level, 1)
	assert_eq(d.hp_max, 1)

func test_holds_fields():
	var d := MonsterDef.new()
	d.display_name = "Goblin"
	d.level = 2
	d.hp_max = 12
	d.might = 6
	d.armor = 1
	d.speed = 9
	d.accuracy = 7
	d.luck = 3
	d.xp_reward = 20
	d.gold_reward = 8
	assert_eq(d.display_name, "Goblin")
	assert_eq(d.hp_max, 12)
	assert_eq(d.might, 6)
	assert_eq(d.armor, 1)
	assert_eq(d.xp_reward, 20)
	assert_eq(d.gold_reward, 8)

func test_drop_defaults_and_fields():
	var d := MonsterDef.new()
	assert_eq(d.drop_item_id, "")
	assert_almost_eq(d.drop_chance, 0.0, 0.0001)
	d.drop_item_id = "potion"; d.drop_chance = 0.5
	assert_eq(d.drop_item_id, "potion")
	assert_almost_eq(d.drop_chance, 0.5, 0.0001)

func test_resistances_default_empty():
	var d := MonsterDef.new()
	assert_eq(d.resistances.size(), 0)
