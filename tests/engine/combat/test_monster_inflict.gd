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

func test_monster_inflicts_poison_on_hit():
	var hero := _char("英雄", 30); hero.speed = 0
	var mon := _monster("毒蛛", 30); mon.accuracy = 999; mon.might = 1; mon.speed = 99
	mon.inflict_kind = StatusEffect.Kind.POISON
	mon.inflict_potency = 2; mon.inflict_duration = 3; mon.inflict_chance = 1.0
	# seed 2：必中（命中上限 95%，seed 1 的擲骰會 miss → 改用會命中的 seed 2，同 test_combat_wake_on_hit）
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(2))
	while not cs.is_over() and cs.current_combatant() is Character:
		cs.party_defend()
	cs.monster_act()
	var has_poison := false
	for s in hero.statuses:
		if s.kind == StatusEffect.Kind.POISON: has_poison = true
	assert_true(has_poison)

func test_dream_wisp_tres_inflicts_sleep_on_hit():
	var def: MonsterDef = load("res://content/monsters/dream_wisp.tres")
	assert_eq(def.inflict_kind, StatusEffect.Kind.SLEEP, "夢魘妖 .tres 應施加睡眠")
	var hero := _char("英雄", 30); hero.speed = 0
	var mon := Monster.from_def(def)
	mon.accuracy = 999; mon.speed = 99; mon.inflict_chance = 1.0
	# seed 2：必中（同 poison 測試說明）
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(2))
	while not cs.is_over() and cs.current_combatant() is Character:
		cs.party_defend()
	cs.monster_act()
	var has_sleep := false
	for s in hero.statuses:
		if s.kind == StatusEffect.Kind.SLEEP: has_sleep = true
	assert_true(has_sleep, "被夢魘妖打中應陷入睡眠")

func test_from_def_carries_inflict():
	var def := MonsterDef.new()
	def.inflict_kind = StatusEffect.Kind.SLEEP
	def.inflict_duration = 2; def.inflict_chance = 0.5
	var m := Monster.from_def(def)
	assert_eq(m.inflict_kind, StatusEffect.Kind.SLEEP)
	assert_eq(m.inflict_chance, 0.5)
