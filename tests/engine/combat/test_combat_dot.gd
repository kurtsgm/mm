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

func test_poison_ticks_damage_on_combat_entry_round():
	var hero := _char("英雄", 30)
	hero.statuses.append(StatusCatalog.poison(4, 5))
	# CombatSystem._init 會跑首個 _start_round → 立即 tick 一次 DoT。
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(1))
	assert_eq(hero.hp, 26)                       # 扣 4
	assert_eq(hero.statuses[0].remaining, 4)     # decay 5→4
	assert_true(cs.drain_events().size() >= 1)   # 有 DoT 事件外溢

func test_poison_can_kill_in_combat():
	var hero := _char("英雄", 3)
	hero.statuses.append(StatusCatalog.poison(5, 5))
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(1))
	assert_eq(hero.hp, 0)
	assert_eq(hero.condition, Character.Condition.UNCONSCIOUS)

func test_combat_start_keeps_poison_drops_others():
	var hero := _char("英雄", 30)
	hero.statuses.append(StatusCatalog.poison(2, 3))
	hero.statuses.append(StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, 2, 3))
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(1))
	assert_eq(hero.statuses.size(), 1)
	assert_eq(hero.statuses[0].kind, StatusEffect.Kind.POISON)

func test_combat_end_keeps_only_persisting():
	var hero := _char("英雄", 30); hero.accuracy = 999   # 命中率封頂 95%；seed 2 首擲必落在命中區間以穩定擊殺
	hero.statuses.append(StatusCatalog.poison(2, 9))
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 1)]), _rng(2))
	hero.statuses.append(StatusCatalog.sleep(9))   # 入場已濾掉睡，重加以測「終局」濾留
	cs.party_attack(0)                              # 擊殺唯一怪 → VICTORY
	assert_true(cs.is_over())
	for s in hero.statuses:
		assert_eq(s.kind, StatusEffect.Kind.POISON)
