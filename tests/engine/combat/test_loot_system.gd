extends GutTest

func before_all():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id; d.category = ItemDef.Category.WEAPON; d.attack = 6; return d

func after_all():
	ItemInstance.base_resolver = Callable()

func _mon(level: int, drop_id: String, drop_chance: float, gear: float) -> Monster:
	var d := MonsterDef.new()
	d.id = "m"; d.level = level; d.drop_item_id = drop_id; d.drop_chance = drop_chance; d.gear_drop_chance = gear
	return Monster.from_def(d)

func _base(id: String, w: int) -> ItemDef:
	var d := ItemDef.new(); d.id = id; d.category = ItemDef.Category.WEAPON
	d.min_level = 1; d.max_level = 100; d.drop_weight = w; d.attack = 6
	return d

func test_fixed_consumable_drop_still_works():
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var res := LootSystem.roll_drops([_mon(5, "potion", 1.0, 0.0)], LootRoller.Source.OVERWORLD, [], rng)
	assert_true((res["item_ids"] as Array).has("potion"))
	assert_eq((res["instances"] as Array).size(), 0)

func test_gear_drop_produces_instance():
	var rng := RandomNumberGenerator.new(); rng.seed = 2
	var res := LootSystem.roll_drops([_mon(30, "", 0.0, 1.0)], LootRoller.Source.OVERWORLD, [_base("w", 10)], rng)
	assert_eq((res["instances"] as Array).size(), 1)
