extends GutTest

func _char(n: String, hp: int, might: int, acc: int, speed: int) -> Character:
	var c := Character.new()
	c.name = n; c.hp = hp; c.hp_max = hp
	c.might = might; c.accuracy = acc; c.speed = speed
	c.condition = Character.Condition.OK
	return c

func _monster(n: String, hp: int, might: int, acc: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = n; m.hp = hp; m.hp_max = hp
	m.might = might; m.armor = 0; m.accuracy = acc; m.speed = speed
	return m

func _party(arr: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for c in arr:
		typed.append(c)
	p.members = typed
	return p

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr:
		out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_strong_party_wins():
	var out := BattleRunner.run(_party([_char("H", 500, 50, 1000, 50)]), _monsters([_monster("M", 8, 1, 1, 1)]), _rng(123))
	assert_eq(out["result"], CombatSystem.Result.VICTORY)
	assert_eq(out["deaths"], 0)
	assert_false(out["timeout"])
	assert_gt(out["rounds"], 0)
	assert_gt(out["hp_pct"], 0.0)

func test_weak_party_loses():
	var out := BattleRunner.run(_party([_char("H", 5, 1, 1, 1)]), _monsters([_monster("M", 100, 50, 1000, 20)]), _rng(123))
	assert_eq(out["result"], CombatSystem.Result.DEFEAT)
	assert_eq(out["deaths"], 1)

func test_outcome_dict_shape():
	var out := BattleRunner.run(_party([_char("H", 100, 20, 80, 20)]), _monsters([_monster("M", 20, 3, 50, 5)]), _rng(5))
	for key in ["result", "rounds", "deaths", "hp_pct", "timeout"]:
		assert_true(out.has(key), "缺 key: %s" % key)
	assert_ne(out["result"], CombatSystem.Result.ONGOING)   # 一定收斂

func test_hp_pct_is_full_on_flawless_win():
	# 必中高傷、怪物極弱且慢 → 玩家不掉血 → hp_pct 接近 1.0
	var out := BattleRunner.run(_party([_char("H", 100, 100, 1000, 50)]), _monsters([_monster("M", 1, 1, 1, 1)]), _rng(9))
	assert_eq(out["result"], CombatSystem.Result.VICTORY)
	assert_almost_eq(out["hp_pct"], 1.0, 0.001)
