extends GutTest

func _char(name: String, hp: int, might: int, acc: int, speed: int) -> Character:
	var c := Character.new()
	c.name = name; c.hp = hp; c.hp_max = hp; c.might = might
	c.accuracy = acc; c.speed = speed; c.condition = Character.Condition.OK
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for m in members: typed.append(m)
	p.members = typed
	return p

func _monster(name: String, hp: int, might: int, acc: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = name; m.hp = hp; m.hp_max = hp; m.might = might
	m.armor = 0; m.accuracy = acc; m.speed = speed
	m.xp_reward = 1; m.gold_reward = 1
	return m

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr: out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s
	return r

func _step_n(cs: CombatSystem, n: int) -> void:
	var i := 0
	while not cs.is_over() and i < n:
		if cs.is_party_turn(): cs.party_attack(0)
		else: cs.monster_act()
		i += 1

func test_party_statuses_cleared_at_combat_start():
	var hero := _char("H", 100, 5, 50, 10)
	hero.statuses.append(StatusEffect.new(StatusEffect.Stat.ACCURACY, 3, 9))
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("M", 50, 1, 1, 1)]), _rng(1))
	assert_eq(hero.statuses.size(), 0, "戰鬥開始清空隊員殘留狀態")

func test_status_decays_and_expires_over_rounds():
	var hero := _char("Hero", 100, 5, 100, 50)   # 快 → 先動
	var mon := _monster("M", 100, 1, 1, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	hero.statuses.append(StatusEffect.new(StatusEffect.Stat.ACCURACY, 3, 2))
	cs.party_attack(0); cs.monster_act()         # 一輪結束 → 新輪 tick：2→1
	assert_eq(hero.statuses.size(), 1)
	assert_eq(hero.statuses[0].remaining, 1)
	cs.party_attack(0); cs.monster_act()         # 又一輪 → tick：1→0 移除
	assert_eq(hero.statuses.size(), 0)

func test_armor_debuff_increases_damage_taken():
	var seed := 55
	var h1 := _char("H", 500, 30, 1000, 50)
	var m1 := _monster("M", 500, 1, 1, 1); m1.armor = 20
	var cs1 := CombatSystem.new(_party([h1]), _monsters([m1]), _rng(seed))
	_step_n(cs1, 4)
	var hp_no_debuff := cs1.living_monsters()[0].hp
	var h2 := _char("H", 500, 30, 1000, 50)
	var m2 := _monster("M", 500, 1, 1, 1); m2.armor = 20
	m2.statuses.append(StatusEffect.new(StatusEffect.Stat.ARMOR, -10, 9))
	var cs2 := CombatSystem.new(_party([h2]), _monsters([m2]), _rng(seed))
	_step_n(cs2, 4)
	var hp_debuffed := cs2.living_monsters()[0].hp
	assert_lt(hp_debuffed, hp_no_debuff, "降低護甲 → 受更多傷")
