extends GutTest

func _char(name: String, hp: int, might: int, acc: int, speed: int) -> Character:
	var c := Character.new()
	c.name = name
	c.hp = hp
	c.hp_max = hp
	c.might = might
	c.accuracy = acc
	c.speed = speed
	c.condition = Character.Condition.OK
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for m in members:
		typed.append(m)
	p.members = typed
	return p

func _monster(name: String, hp: int, might: int, acc: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = name
	m.hp = hp
	m.hp_max = hp
	m.might = might
	m.armor = 0
	m.accuracy = acc
	m.speed = speed
	m.xp_reward = 10
	m.gold_reward = 5
	return m

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr:
		out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _run_to_end(cs: CombatSystem, cap: int) -> void:
	var n := 0
	while not cs.is_over() and n < cap:
		if cs.is_party_turn():
			cs.party_attack(0)
		else:
			cs.monster_act()
		n += 1

func test_faster_party_acts_first():
	var hero := _char("Hero", 50, 20, 80, 20)
	var mon := _monster("Slow", 50, 5, 50, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	assert_true(cs.is_party_turn())

func test_faster_monster_acts_first():
	var hero := _char("Hero", 50, 20, 80, 1)
	var mon := _monster("Fast", 50, 5, 50, 20)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	assert_false(cs.is_party_turn())

func test_party_wins_when_stronger():
	var hero := _char("Hero", 100, 50, 1000, 20)
	var mon := _monster("Weak", 8, 1, 1, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(123))
	_run_to_end(cs, 200)
	assert_eq(cs.result(), CombatSystem.Result.VICTORY)
	assert_false(mon.is_alive())
	assert_true(hero.is_conscious())
	assert_null(cs.current_combatant())

func test_party_defeated_when_weaker():
	var hero := _char("Hero", 5, 1, 1, 1)
	var mon := _monster("Strong", 100, 50, 1000, 20)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(123))
	_run_to_end(cs, 500)
	assert_eq(cs.result(), CombatSystem.Result.DEFEAT)
	assert_true(cs.party.is_wiped())

func test_victory_requires_all_monsters_dead():
	var hero := _char("Hero", 300, 50, 1000, 20)
	var a := _monster("A", 6, 1, 1, 5)
	var b := _monster("B", 6, 1, 1, 4)
	var cs := CombatSystem.new(_party([hero]), _monsters([a, b]), _rng(7))
	_run_to_end(cs, 300)
	assert_eq(cs.result(), CombatSystem.Result.VICTORY)
	assert_false(a.is_alive())
	assert_false(b.is_alive())

func test_unconscious_member_excluded_from_turn_order():
	var hero := _char("Hero", 50, 20, 80, 20)
	var ko := _char("KO", 0, 20, 80, 99)
	ko.condition = Character.Condition.UNCONSCIOUS
	var mon := _monster("Mon", 50, 5, 50, 1)
	var cs := CombatSystem.new(_party([hero, ko]), _monsters([mon]), _rng(1))
	# ko speed 99 最快，但已昏迷 → 不在順序 → 首位是 hero
	assert_true(cs.is_party_turn())
	assert_eq(cs.current_combatant().name, "Hero")
