extends GutTest

func _char(name: String, cls: String, level: int) -> Character:
	var c := Character.new()
	c.name = name
	c.char_class = cls
	c.level = level
	c.hp_max = 20; c.hp = 20
	c.sp_max = 5; c.sp = 5
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	for m in members:
		p.members.append(m)
	return p

func test_party_min_and_avg_level():
	var p := _party([_char("A", "Knight", 2), _char("B", "Cleric", 4)])
	assert_eq(ProgressionSim.party_min_level(p), 2)
	assert_almost_eq(ProgressionSim.party_avg_level(p), 3.0, 0.001)

func test_full_rest_restores_and_revives():
	var c := _char("A", "Knight", 2)
	c.hp = 0; c.sp = 0; c.condition = Character.Condition.UNCONSCIOUS
	var p := _party([c])
	ProgressionSim.full_rest(p)
	assert_eq(c.hp, c.hp_max)
	assert_eq(c.sp, c.sp_max)
	assert_eq(c.condition, Character.Condition.OK)

func test_grant_fight_xp_splits_among_conscious():
	var a := _char("A", "Knight", 1)
	var b := _char("B", "Knight", 1)
	b.condition = Character.Condition.UNCONSCIOUS   # 昏迷不分 XP
	var p := _party([a, b])
	var ups := ProgressionSim.grant_fight_xp(p, 80)   # 清醒只有 A → share 80 ≥ xp_for_level(1)=40
	assert_gt(a.level, 1, "A 應升級")
	assert_eq(b.level, 1, "昏迷 B 不得 XP")
	assert_gt(ups, 0)

func test_fights_per_level_tally():
	var got := ProgressionSim.fights_per_level([1, 1, 1, 2, 2, 3])
	assert_eq(got[1], 3)
	assert_eq(got[2], 2)
	assert_eq(got[3], 1)

func test_clone_party_is_independent_and_full():
	var a := _char("A", "Knight", 3)
	a.might = 18; a.hp = 5; a.condition = Character.Condition.UNCONSCIOUS
	var p := _party([a])
	var clone := ProgressionSim.clone_party(p)
	var ca := clone.members[0]
	assert_eq(ca.might, 18)
	assert_eq(ca.level, 3)
	assert_eq(ca.hp, ca.hp_max)              # 複本全休
	assert_eq(ca.condition, Character.Condition.OK)
	ca.might = 1                              # 改複本不影響原本
	assert_eq(a.might, 18)

func test_estimate_encounter_schema_and_determinism():
	var p := SimPartyBuilder.build(3)
	var a := ProgressionSim.estimate_encounter(p, "g", 6, 99, Bestiary)
	for key in ["win_rate", "avg_rounds", "xp_total", "efficiency"]:
		assert_true(a.has(key), "缺 key %s" % key)
	assert_true(a["win_rate"] >= 0.0 and a["win_rate"] <= 1.0)
	assert_gt(a["xp_total"], 0)                       # goblin 組總 xp
	var b := ProgressionSim.estimate_encounter(p, "g", 6, 99, Bestiary)
	assert_eq(a["win_rate"], b["win_rate"])           # 同 seed 可複現

func test_run_reaches_target_and_records():
	var rep := ProgressionSim.run(4, 12345, 8, 0.7, 500, Bestiary)   # 舊 ogre 可達 L4
	assert_true(rep["reached_target"], "應能練到 L4")
	assert_true(rep["final_min_level"] >= 4)
	assert_gt(rep["fights"].size(), 0)
	# fights_per_level 的總場數 = fights 數
	var sum := 0
	for k in rep["fights_per_level"]:
		sum += int(rep["fights_per_level"][k])
	assert_eq(sum, rep["fights"].size())

func test_run_level_curve_non_decreasing():
	var rep := ProgressionSim.run(4, 222, 8, 0.7, 500, Bestiary)
	var prev := 0.0
	for f in rep["fights"]:
		assert_true(f["avg_level"] >= prev, "平均等級不應下降")
		prev = f["avg_level"]

func test_estimate_encounter_uses_bestiary_override():
	# 傳 TierBestiary → 用 tier 遭遇（xp_total = swarm 群 t1 的總 xp，> 0）
	var p := SimPartyBuilder.build(3)
	var est := ProgressionSim.estimate_encounter(p, "t1_swarm", 4, 7, TierBestiary)
	assert_gt(est["xp_total"], 0)
	# 同 id 用舊 Bestiary 不認得 → xp_total 0
	var legacy := ProgressionSim.estimate_encounter(p, "t1_swarm", 4, 7, Bestiary)
	assert_eq(legacy["xp_total"], 0)
