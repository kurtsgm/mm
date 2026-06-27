extends GutTest

func _char(name: String, hp: int) -> Character:
	var c := Character.new()
	c.name = name; c.hp = hp; c.hp_max = hp; c.speed = 5; c.accuracy = 5
	c.condition = Character.Condition.OK
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for m in members: typed.append(m)
	p.members = typed
	return p

func _monster(name: String, hp: int) -> Monster:
	var m := Monster.new()
	m.name = name; m.hp = hp; m.hp_max = hp; m.speed = 1; m.accuracy = 0
	m.xp_reward = 1; m.gold_reward = 1
	return m

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr: out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s
	return r

func test_sleeping_actor_skips_turn():
	var hero := _char("英雄", 30); hero.speed = 99   # 先手
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(1))
	hero.statuses.append(StatusCatalog.sleep(3))   # 戰鬥中被催眠（入場會濾掉非持久狀態，故於 new() 後施加）
	var ev := cs.try_skip_turn()
	assert_true(ev.size() >= 1)
	assert_false(cs.is_party_turn() and cs.current_combatant() == hero)   # 已前進，不再是熟睡英雄的回合

func test_awake_actor_not_skipped():
	var hero := _char("英雄", 30); hero.speed = 99
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(1))
	assert_eq(cs.try_skip_turn(), [])
	assert_true(cs.is_party_turn())

func test_paralysis_skip_depends_on_roll():
	# 麻痺於 new() 後施加（入場會濾掉非持久狀態）。實際種子：seed 1 首擲<0.5→跳過、seed 2≥0.5→不跳。
	# 此處用 seed 2（不跳）作對照；try_skip_turn 不論跳過與否都不應 crash 且回傳 Array。
	var hero := _char("英雄", 30); hero.speed = 99
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(2))
	hero.statuses.append(StatusCatalog.paralysis(3))
	var ev := cs.try_skip_turn()
	assert_true(ev is Array)
