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
