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

func test_eligible_excludes_artifacts():
	var elig := UniqueCatalog.eligible(100)
	assert_true(elig.has("dawnblade"), "一般 unique 仍在池內")
	assert_false(elig.has("starender_blade"), "神器不入隨機池")
	assert_false(elig.has("choir_crown"), "神器不入隨機池")

func test_is_artifact_and_list():
	assert_true(UniqueCatalog.is_artifact("eternal_lamp"))
	assert_false(UniqueCatalog.is_artifact("dawnblade"))
	assert_eq(UniqueCatalog.artifacts().size(), 7)

func test_make_artifact_instance():
	var it := UniqueCatalog.make("starender_blade")
	assert_not_null(it)
	assert_eq(it.unique_id, "starender_blade")
	assert_eq(it.base_id, "dragonbone_sword")
	assert_eq(it.quality, Quality.Q.MYTHIC)
	assert_eq(it.ilvl, 65)
	assert_eq(it.display_name(), "弒星之刃")
	assert_eq(it.total_stat(ItemStat.S.ATTACK), 28)

func test_make_regular_unique_is_legendary():
	var it := UniqueCatalog.make("dawnblade")
	assert_eq(it.quality, Quality.Q.LEGENDARY)

func test_make_unknown_returns_null():
	assert_null(UniqueCatalog.make("nope"))
