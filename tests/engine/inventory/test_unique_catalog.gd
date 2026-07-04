extends GutTest

func test_eligible_by_ilvl():
	assert_true(UniqueCatalog.eligible(60).has("dawnblade"))
	assert_false(UniqueCatalog.eligible(5).has("dawnblade"))

func test_entry_shape():
	var e := UniqueCatalog.entry("dawnblade")
	assert_eq(String(e["name"]), "弐光之刃")
	assert_eq(String(e["base_id"]), "steel_blade")
	assert_true((e["mods"] as Dictionary).has(ItemStat.S.ATTACK))

func test_artifact_entries():
	var ids := ["eternal_lamp", "genesis_casket", "stasis_reliquary",
		"wayfinder_astrolabe", "starender_blade", "choir_crown", "aegis_field_core"]
	for aid in ids:
		var e := UniqueCatalog.entry(aid)
		assert_false(e.is_empty(), "神器 %s 應存在" % aid)
		assert_true(bool(e.get("is_artifact", false)), "%s is_artifact" % aid)
		assert_eq(String(e.get("set_id", "")), "seven_relics", "%s set_id" % aid)
		assert_true((e["mods"] as Dictionary).size() >= 1, "%s 至少一條 mod" % aid)

func test_artifact_names_unique():
	var names := {}
	for aid in ["eternal_lamp", "genesis_casket", "stasis_reliquary",
		"wayfinder_astrolabe", "starender_blade", "choir_crown", "aegis_field_core"]:
		var nm := String(UniqueCatalog.entry(aid)["name"])
		assert_false(names.has(nm), "神器名重複：%s" % nm)
		names[nm] = true
