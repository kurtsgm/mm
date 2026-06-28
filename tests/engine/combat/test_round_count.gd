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

func test_round_count_starts_at_one():
	var cs := CombatSystem.new(_party([_char("H", 100, 1, 80, 50)]), _monsters([_monster("M", 100, 1, 50, 1)]), _rng(1))
	assert_eq(cs.round_count, 1)

func test_round_count_increments_after_full_round():
	# 雙方高血低傷，一整輪結束都不會死 → 進新一輪 round_count 應變 2
	var hero := _char("H", 100, 1, 80, 50)   # 比怪快、先動
	var mon := _monster("M", 100, 1, 50, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(2))
	cs.party_attack(0)   # 隊員行動
	cs.monster_act()     # 怪物行動 → 本輪結束 → _start_round 再跑一次
	assert_eq(cs.round_count, 2)
