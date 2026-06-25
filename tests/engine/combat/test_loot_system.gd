extends GutTest

func _mon(drop_id: String, chance: float) -> Monster:
	var m := Monster.new()
	m.name = "M"; m.hp = 1; m.hp_max = 1
	m.drop_item_id = drop_id; m.drop_chance = chance
	return m

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1
	return r

func test_certain_drop_always_drops():
	var drops := LootSystem.roll_drops([_mon("potion", 1.0)], _rng())
	assert_eq(drops.size(), 1)
	assert_true(drops.has("potion"))

func test_zero_chance_never_drops():
	var drops := LootSystem.roll_drops([_mon("potion", 0.0)], _rng())
	assert_eq(drops.size(), 0)

func test_empty_drop_id_never_drops():
	var drops := LootSystem.roll_drops([_mon("", 1.0)], _rng())
	assert_eq(drops.size(), 0)

func test_multiple_monsters_accumulate_certain_drops():
	var drops := LootSystem.roll_drops([_mon("potion", 1.0), _mon("ether", 1.0), _mon("", 1.0)], _rng())
	assert_eq(drops.size(), 2)
	assert_true(drops.has("potion"))
	assert_true(drops.has("ether"))
