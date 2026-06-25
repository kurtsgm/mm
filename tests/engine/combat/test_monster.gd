extends GutTest

func _def() -> MonsterDef:
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
	return d

func test_from_def_copies_fields_and_starts_full_hp():
	var m := Monster.from_def(_def())
	assert_eq(m.name, "Goblin")
	assert_eq(m.level, 2)
	assert_eq(m.hp, 12)
	assert_eq(m.hp_max, 12)
	assert_eq(m.might, 6)
	assert_eq(m.armor, 1)
	assert_eq(m.speed, 9)
	assert_eq(m.accuracy, 7)
	assert_eq(m.luck, 3)
	assert_eq(m.xp_reward, 20)
	assert_eq(m.gold_reward, 8)

func test_is_alive():
	var m := Monster.from_def(_def())
	assert_true(m.is_alive())
	m.hp = 0
	assert_false(m.is_alive())
	m.hp = -3
	assert_false(m.is_alive())

func test_from_def_copies_drop_fields():
	var def := MonsterDef.new()
	def.display_name = "G"; def.hp_max = 10
	def.drop_item_id = "potion"; def.drop_chance = 0.25
	var m := Monster.from_def(def)
	assert_eq(m.drop_item_id, "potion")
	assert_almost_eq(m.drop_chance, 0.25, 0.0001)
