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

func test_monster_hit_wakes_sleeping_hero():
	var hero := _char("英雄", 30); hero.speed = 0
	var mon := _monster("狼", 30); mon.accuracy = 999; mon.might = 1; mon.speed = 99
	# seed 2：必中（命中上限 95%，seed 1 的擲骰會 miss → 改用會命中的 seed 2）
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(2))
	# 戰鬥入場會清掉隊員非持久狀態（_strip_party_to_persisting），故 sleep 於 new() 後施加
	hero.statuses.append(StatusCatalog.sleep(5))
	# 推進到怪物回合並讓牠打英雄
	while not cs.is_over() and cs.current_combatant() is Character:
		cs.party_defend()
	cs.monster_act()
	var has_sleep := false
	for s in hero.statuses:
		if s.kind == StatusEffect.Kind.SLEEP: has_sleep = true
	assert_false(has_sleep)   # 受擊後睡眠解除

func test_spell_damage_wakes_sleeping_monster():
	var hero := _char("法師", 30); hero.speed = 99; hero.intellect = 10
	hero.sp = 10; hero.sp_max = 10   # _char helper 不設 SP；spark 需 2 SP，否則施法被拒
	hero.known_spells = ["spark"]
	var mon := _monster("靶", 30); mon.speed = 0
	mon.statuses.append(StatusCatalog.sleep(5))
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	cs.party_cast(SpellBook.get_spell("spark"), 0)
	var has_sleep := false
	for s in mon.statuses:
		if s.kind == StatusEffect.Kind.SLEEP: has_sleep = true
	assert_false(has_sleep)
