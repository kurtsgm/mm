extends GutTest

func test_archetypes_list():
	var a := MonsterTiers.archetypes()
	for name in ["brute", "skirmisher", "swarm", "ailment"]:
		assert_true(a.has(name), "缺 archetype %s" % name)

func test_make_def_id_and_level():
	var d := MonsterTiers.make_def(3, "brute")
	assert_eq(d.id, "t3_brute")
	assert_eq(d.level, 30)            # 10 * tier
	assert_gt(d.hp_max, 0)
	assert_gt(d.might, 0)

func test_tier_scaling_monotonic():
	# 每升一 tier，各核心 stat 與 xp_reward 不減
	var lo := MonsterTiers.make_def(2, "brute")
	var hi := MonsterTiers.make_def(7, "brute")
	assert_gt(hi.hp_max, lo.hp_max)
	assert_gt(hi.might, lo.might)
	assert_gt(hi.xp_reward, lo.xp_reward)

func test_archetype_distinctions_same_tier():
	var brute := MonsterTiers.make_def(5, "brute")
	var skirm := MonsterTiers.make_def(5, "skirmisher")
	assert_gt(brute.hp_max, skirm.hp_max)       # 坦 > 遊擊 血量
	assert_gt(skirm.speed, brute.speed)         # 遊擊 > 坦 速度

func test_ailment_inflicts_poison():
	var d := MonsterTiers.make_def(4, "ailment")
	assert_eq(d.inflict_kind, StatusEffect.Kind.POISON)
	assert_gt(d.inflict_potency, 0)
	assert_gt(d.inflict_duration, 0)
	assert_gt(d.inflict_chance, 0.0)

func test_non_ailment_does_not_inflict():
	assert_eq(MonsterTiers.make_def(4, "brute").inflict_kind, -1)

func test_group_count():
	assert_eq(MonsterTiers.group_count("brute"), 1)
	assert_eq(MonsterTiers.group_count("swarm"), 4)
	assert_eq(MonsterTiers.group_count("skirmisher"), 2)

func test_tier_10_caps_at_level_100():
	assert_eq(MonsterTiers.make_def(10, "brute").level, 100)
