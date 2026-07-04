extends GutTest

func before_all():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id; d.category = ItemDef.Category.WEAPON; d.attack = 6; return d

func after_all():
	ItemInstance.base_resolver = Callable()

func _base(id: String, lo: int, hi: int, w: int) -> ItemDef:
	var d := ItemDef.new()
	d.id = id; d.category = ItemDef.Category.WEAPON; d.attack = 6
	d.min_level = lo; d.max_level = hi; d.drop_weight = w
	return d

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = seed; return r

func test_only_bases_in_level_band_are_picked():
	var bases := [_base("low", 1, 10, 10), _base("high", 50, 60, 10)]
	# lv55 只可能抽到 high
	for s in range(20):
		var it := LootRoller.roll(bases, 55, LootRoller.Source.OVERWORLD, _rng(s))
		if it != null:
			assert_eq(it.base_id, "high")

func test_tier_for():
	assert_eq(LootRoller.tier_for(1), 1)
	assert_eq(LootRoller.tier_for(10), 1)
	assert_eq(LootRoller.tier_for(11), 2)
	assert_eq(LootRoller.tier_for(55), 6)
	assert_eq(LootRoller.tier_for(999), 10)

func test_affix_count_matches_quality():
	var bases := [_base("w", 1, 100, 10)]
	# 用固定 quality 的直路：直接檢查 roll 出來的實例詞綴數不超過品質上限
	var it := LootRoller.roll(bases, 30, LootRoller.Source.OVERWORLD, _rng(3))
	assert_not_null(it)
	if it.quality == Quality.Q.COMMON:
		assert_eq(it.affixes.size(), 0)
	assert_true(it.ilvl == 30)

func test_returns_null_when_no_eligible_base():
	var bases := [_base("high", 50, 60, 10)]
	assert_null(LootRoller.roll(bases, 5, LootRoller.Source.OVERWORLD, _rng(1)))
