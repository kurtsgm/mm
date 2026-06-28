extends GutTest

func test_all_ids_covers_10_tiers_x_4_archetypes():
	var ids := TierBestiary.all_ids()
	assert_eq(ids.size(), 40)               # 10 tier × 4 archetype
	assert_true(ids.has("t1_brute"))
	assert_true(ids.has("t10_ailment"))

func test_group_defs_for_swarm_has_count():
	var defs := TierBestiary.group_defs_for("t3_swarm")
	assert_eq(defs.size(), 4)               # swarm group_count = 4
	for d in defs:
		assert_eq(d.id, "t3_swarm")
		assert_eq(d.level, 30)

func test_group_defs_for_brute_single():
	var defs := TierBestiary.group_defs_for("t5_brute")
	assert_eq(defs.size(), 1)
	assert_eq(defs[0].id, "t5_brute")

func test_unknown_id_returns_empty():
	assert_eq(TierBestiary.group_defs_for("nope").size(), 0)
	assert_eq(TierBestiary.group_defs_for("t11_brute").size(), 0)   # tier 超出 1..10
