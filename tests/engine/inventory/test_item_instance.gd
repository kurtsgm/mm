extends GutTest

func _sword_def() -> ItemDef:
	var d := ItemDef.new()
	d.id = "iron_sword"; d.display_name = "鐵劍"; d.category = ItemDef.Category.WEAPON
	d.attack = 6; d.value = 30
	return d

func before_each():
	ItemInstance.base_resolver = func(id): return _sword_def() if id == "iron_sword" else null

func after_each():
	ItemInstance.base_resolver = Callable()

func _inst(quality: int, affixes: Array) -> ItemInstance:
	var it := ItemInstance.new()
	it.base_id = "iron_sword"; it.quality = quality; it.ilvl = 20; it.affixes = affixes
	return it

func test_common_uses_base_name_and_attack():
	var it := _inst(Quality.Q.COMMON, [])
	assert_eq(it.display_name(), "鐵劍")
	assert_eq(it.total_attack(), 6)

func test_affix_attack_and_stat_and_name():
	var it := _inst(Quality.Q.RARE, [
		{"id": "sharp", "kind": AffixCatalog.PREFIX, "mods": {ItemStat.S.ATTACK: 4}},
		{"id": "of_the_bear", "kind": AffixCatalog.SUFFIX, "mods": {ItemStat.S.MIGHT: 5}},
	])
	assert_eq(it.total_attack(), 10)                         # 6 + 4
	assert_eq(it.total_stat(ItemStat.S.MIGHT), 5)
	assert_eq(it.display_name(), "鋒利的鐵劍·熊之力")

func test_unique_uses_unique_name_and_mods():
	var it := ItemInstance.new()
	it.base_id = "iron_sword"; it.quality = Quality.Q.LEGENDARY; it.ilvl = 50; it.unique_id = "whisperwind"
	assert_eq(it.display_name(), "耳語之風")
	assert_eq(it.total_stat(ItemStat.S.SPEED), 8)

func test_to_from_dict_roundtrip():
	var it := _inst(Quality.Q.FINE, [{"id": "sharp", "kind": AffixCatalog.PREFIX, "mods": {ItemStat.S.ATTACK: 3}}])
	var back := ItemInstance.from_dict(it.to_dict())
	assert_eq(back.base_id, "iron_sword")
	assert_eq(back.quality, Quality.Q.FINE)
	assert_eq(back.total_attack(), 9)

func test_sell_value_scales_with_quality():
	assert_eq(_inst(Quality.Q.COMMON, []).sell_value(), 30)  # 30 * 1.0
	assert_eq(_inst(Quality.Q.RARE, []).sell_value(), 105)   # 30 * 3.5
