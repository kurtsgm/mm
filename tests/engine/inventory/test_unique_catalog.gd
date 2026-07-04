extends GutTest

func test_eligible_by_ilvl():
	assert_true(UniqueCatalog.eligible(60).has("dawnblade"))
	assert_false(UniqueCatalog.eligible(5).has("dawnblade"))

func test_entry_shape():
	var e := UniqueCatalog.entry("dawnblade")
	assert_eq(String(e["name"]), "弐光之刃")
	assert_eq(String(e["base_id"]), "steel_blade")
	assert_true((e["mods"] as Dictionary).has(ItemStat.S.ATTACK))
