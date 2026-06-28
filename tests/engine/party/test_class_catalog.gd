extends GutTest

const KEYS := ["might", "intellect", "personality", "endurance", "speed", "accuracy", "luck", "hp_max", "sp_max"]

func test_all_classes_present():
	var cs := ClassCatalog.all_classes()
	for name in ["Knight", "Paladin", "Archer", "Cleric", "Sorcerer", "Robber"]:
		assert_true(cs.has(name), "缺職業 %s" % name)
		assert_true(ClassCatalog.has_class(name))

func test_every_class_has_all_keys():
	for name in ClassCatalog.all_classes():
		var base := ClassCatalog.base_stats(name)
		var grow := ClassCatalog.growth(name)
		for k in KEYS:
			assert_true(base.has(k), "%s base 缺 %s" % [name, k])
			assert_true(grow.has(k), "%s growth 缺 %s" % [name, k])

func test_stats_at_level_one_equals_base():
	var base := ClassCatalog.base_stats("Knight")
	var l1 := ClassCatalog.stats_at_level("Knight", 1)
	for k in KEYS:
		assert_eq(l1[k], base[k], "Knight L1 %s 應等於 base" % k)

func test_stats_at_level_linear_growth():
	# Knight: hp_max base 30, +6/級 → L3 = 30 + 2*6 = 42；might base 16 +1/級 → L3 = 18
	var l3 := ClassCatalog.stats_at_level("Knight", 3)
	assert_eq(l3["hp_max"], 42)
	assert_eq(l3["might"], 18)
	assert_eq(l3["endurance"], 20)   # base 18 + 2

func test_class_identity_sorcerer_vs_knight():
	var k := ClassCatalog.base_stats("Knight")
	var s := ClassCatalog.base_stats("Sorcerer")
	assert_gt(k["endurance"], s["endurance"])   # 坦 > 法
	assert_gt(s["intellect"], k["intellect"])   # 法 > 坦
	assert_gt(s["sp_max"], k["sp_max"])

func test_unknown_class_returns_zeros():
	assert_false(ClassCatalog.has_class("Bard"))
	var z := ClassCatalog.stats_at_level("Bard", 5)
	for k in KEYS:
		assert_eq(z[k], 0)
