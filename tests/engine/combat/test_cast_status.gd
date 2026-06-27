extends GutTest

func _char(name: String, hp: int) -> Character:
	var c := Character.new()
	c.name = name; c.hp = hp; c.hp_max = hp; c.speed = 5; c.accuracy = 5
	c.sp = 10; c.sp_max = 10
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

func test_cast_sleep_applies_sleep_to_enemy():
	var hero := _char("法師", 30); hero.speed = 99; hero.known_spells = ["sleep"]
	var mon := _monster("靶", 30); mon.speed = 0
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	cs.party_cast(SpellBook.get_spell("sleep"), 0)
	var has_sleep := false
	for s in mon.statuses:
		if s.kind == StatusEffect.Kind.SLEEP: has_sleep = true
	assert_true(has_sleep)

func test_cast_poison_applies_poison():
	var hero := _char("法師", 30); hero.speed = 99; hero.known_spells = ["poison"]
	var mon := _monster("靶", 30); mon.speed = 0
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	cs.party_cast(SpellBook.get_spell("poison"), 0)
	var has_poison := false
	for s in mon.statuses:
		if s.kind == StatusEffect.Kind.POISON: has_poison = true
	assert_true(has_poison)

func test_existing_weaken_still_stat_mod():
	var hero := _char("法師", 30); hero.speed = 99; hero.known_spells = ["weaken"]
	var mon := _monster("靶", 30); mon.speed = 0; mon.armor = 5
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	cs.party_cast(SpellBook.get_spell("weaken"), 0)
	assert_eq(mon.statuses[0].kind, StatusEffect.Kind.STAT_MOD)
	assert_true(mon.effective_armor() < 5)
