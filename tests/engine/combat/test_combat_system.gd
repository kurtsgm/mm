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

func test_defend_marks_actor_and_clears_next_round():
	var hero := _char("Hero", 100, 5, 80, 50)   # 比怪物快 → 先動
	var mon := _monster("Mon", 100, 5, 50, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(2))
	assert_true(cs.is_party_turn())
	cs.party_defend()
	assert_true(cs.is_defending(hero))   # 本輪防禦中
	cs.monster_act()                      # 怪物行動，輪結束 → 進新一輪
	assert_false(cs.is_defending(hero))   # 新一輪清除

func test_flee_chance_monotonic_and_clamped():
	var fast := _char("Fast", 100, 1, 1, 50)
	var slow := _char("Slow", 100, 1, 1, 1)
	var quick_mon := _monster("Q", 100, 1, 1, 50)
	var slow_mon := _monster("S", 100, 1, 1, 1)
	var cs_easy := CombatSystem.new(_party([fast]), _monsters([slow_mon]), _rng(1))
	var cs_hard := CombatSystem.new(_party([slow]), _monsters([quick_mon]), _rng(1))
	assert_gt(cs_easy.flee_chance(), cs_hard.flee_chance())
	assert_true(cs_easy.flee_chance() <= 95)
	assert_true(cs_hard.flee_chance() >= 10)

func test_run_success_eventually_when_much_faster():
	var hero := _char("Hero", 100, 1, 1, 50)
	var mon := _monster("Mon", 100, 1, 1, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(3))
	var tries := 0
	while not cs.is_over() and tries < 50:
		if cs.is_party_turn():
			cs.party_run()
		else:
			cs.monster_act()
		tries += 1
	assert_eq(cs.result(), CombatSystem.Result.FLED)
	assert_true(cs.is_over())

func test_run_outcome_is_consistent():
	var hero := _char("Hero", 100, 1, 1, 50)
	var mon := _monster("Mon", 100, 1, 1, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(8))
	assert_true(cs.is_party_turn())
	cs.party_run()
	if cs.result() == CombatSystem.Result.FLED:
		assert_true(cs.is_over())
	else:
		assert_eq(cs.result(), CombatSystem.Result.ONGOING)
		assert_false(cs.is_party_turn())  # 逃跑失敗也消耗回合

func _weapon(attack: int) -> ItemDef:
	var d := ItemDef.new()
	d.category = ItemDef.Category.WEAPON; d.attack = attack
	return d

func _armor_item(armor: int) -> ItemDef:
	var d := ItemDef.new()
	d.category = ItemDef.Category.ARMOR; d.armor = armor
	return d

func _step_n(cs: CombatSystem, n: int) -> void:
	var i := 0
	while not cs.is_over() and i < n:
		if cs.is_party_turn():
			cs.party_attack(0)
		else:
			cs.monster_act()
		i += 1

func test_equipped_weapon_increases_outgoing_damage():
	var seed := 77
	var h1 := _char("H", 500, 1, 1000, 50)   # 快、高命中、無武器；might=1
	var cs1 := CombatSystem.new(_party([h1]), _monsters([_monster("M", 500, 1, 1, 1)]), _rng(seed))
	_step_n(cs1, 6)
	var hp1 := cs1.living_monsters()[0].hp
	var h2 := _char("H", 500, 1, 1000, 50)
	h2.equipment.equip(_weapon(20))
	var cs2 := CombatSystem.new(_party([h2]), _monsters([_monster("M", 500, 1, 1, 1)]), _rng(seed))
	_step_n(cs2, 6)
	var hp2 := cs2.living_monsters()[0].hp
	assert_lt(hp2, hp1, "裝備武器應提高輸出，怪物剩血更少")

func test_equipped_armor_reduces_incoming_damage():
	var seed := 99
	var h1 := _char("H", 200, 1, 1, 1)       # 慢 → 怪物先動；無防具
	var cs1 := CombatSystem.new(_party([h1]), _monsters([_monster("M", 500, 8, 1000, 50)]), _rng(seed))
	_step_n(cs1, 8)
	var h2 := _char("H", 200, 1, 1, 1)
	h2.equipment.equip(_armor_item(100))     # armor_value 100 → 入傷夾到最低
	var cs2 := CombatSystem.new(_party([h2]), _monsters([_monster("M", 500, 8, 1000, 50)]), _rng(seed))
	_step_n(cs2, 8)
	assert_gt(h2.hp, h1.hp, "裝甲應減少受到的傷害")

func test_monster_act_emits_damaged_on_target():
	var hero := _char("Hero", 50, 1, 1, 1)        # 慢 → 怪物先動
	var mon := _monster("Mon", 100, 5, 1000, 20)  # 高命中（命中率上限 95%）
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(2))  # seed 2 → 命中（seed 1 會 miss）
	assert_false(cs.is_party_turn())
	watch_signals(hero)
	cs.monster_act()
	assert_signal_emitted(hero, "damaged")
	assert_lt(hero.hp, 50)

func test_monster_act_kos_member_at_zero_hp():
	var hero := _char("Hero", 3, 1, 1, 1)
	var mon := _monster("Mon", 100, 50, 1000, 20)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(2))  # seed 2 → 命中（seed 1 會 miss）
	cs.monster_act()
	assert_eq(hero.hp, 0)
	assert_eq(hero.condition, Character.Condition.UNCONSCIOUS)
