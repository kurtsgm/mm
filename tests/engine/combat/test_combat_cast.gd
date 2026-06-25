extends GutTest

func _char(name: String, hp: int, sp: int, acc: int, speed: int) -> Character:
	var c := Character.new()
	c.name = name; c.hp = hp; c.hp_max = hp; c.sp = sp; c.sp_max = sp
	c.accuracy = acc; c.speed = speed; c.might = 1; c.condition = Character.Condition.OK
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for m in members: typed.append(m)
	p.members = typed
	return p

func _monster(name: String, hp: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = name; m.hp = hp; m.hp_max = hp; m.might = 1
	m.armor = 0; m.accuracy = 1; m.speed = speed
	m.xp_reward = 1; m.gold_reward = 1
	return m

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr: out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s
	return r

func _damage(id: String, target: int, power: int, sp: int, element: int = SpellDef.Element.MAGIC) -> SpellDef:
	var s := SpellDef.new()
	s.id = id; s.effect = SpellDef.Effect.DAMAGE; s.target = target
	s.power = power; s.sp_cost = sp; s.element = element
	return s

func test_damage_spell_reduces_hp_and_sp():
	var mage := _char("Mage", 50, 10, 50, 50)   # 快 → 先動
	mage.known_spells = ["bolt"]
	var mon := _monster("M", 100, 1)
	var cs := CombatSystem.new(_party([mage]), _monsters([mon]), _rng(5))
	assert_true(cs.is_party_turn())
	var ev := cs.party_cast(_damage("bolt", SpellDef.Target.SINGLE_ENEMY, 10, 3), 0)
	assert_lt(mon.hp, 100, "敵人受傷")
	assert_eq(mage.sp, 7, "扣 3 SP")
	assert_gt(ev.size(), 0)

func test_aoe_damages_all_enemies():
	var mage := _char("Mage", 50, 10, 50, 50)
	mage.known_spells = ["wave"]
	var a := _monster("A", 100, 1)
	var b := _monster("B", 100, 1)
	var cs := CombatSystem.new(_party([mage]), _monsters([a, b]), _rng(9))
	cs.party_cast(_damage("wave", SpellDef.Target.ALL_ENEMIES, 8, 4), 0)
	assert_lt(a.hp, 100)
	assert_lt(b.hp, 100)

func test_heal_spell_restores_ally():
	var cleric := _char("Cleric", 50, 10, 50, 50)
	cleric.known_spells = ["cure"]
	var hurt := _char("Hurt", 30, 0, 10, 5); hurt.hp = 10
	var cs := CombatSystem.new(_party([cleric, hurt]), _monsters([_monster("M", 100, 1)]), _rng(3))
	var heal := SpellDef.new()
	heal.id = "cure"; heal.effect = SpellDef.Effect.HEAL
	heal.target = SpellDef.Target.SINGLE_ALLY; heal.power = 8; heal.sp_cost = 2
	cs.party_cast(heal, 1)   # 隊伍 index 1 = Hurt
	assert_eq(hurt.hp, 18, "10 + 8")
	assert_eq(cleric.sp, 8)

func test_buff_applies_status_and_changes_accuracy():
	var mage := _char("Mage", 50, 10, 20, 50)
	mage.known_spells = ["bless"]
	var cs := CombatSystem.new(_party([mage]), _monsters([_monster("M", 100, 1)]), _rng(1))
	var bless := SpellDef.new()
	bless.id = "bless"; bless.effect = SpellDef.Effect.BUFF
	bless.target = SpellDef.Target.ALL_ALLIES
	bless.status_stat = StatusEffect.Stat.ACCURACY
	bless.status_amount = 3; bless.status_duration = 3; bless.sp_cost = 2
	cs.party_cast(bless, 0)
	assert_eq(mage.statuses.size(), 1)
	assert_eq(mage.effective_accuracy(), 23, "20 + 3")

func test_unknown_spell_rejected_no_cost_no_advance():
	var mage := _char("Mage", 50, 10, 50, 50)   # 不會任何法術
	var cs := CombatSystem.new(_party([mage]), _monsters([_monster("M", 100, 1)]), _rng(1))
	var ev := cs.party_cast(_damage("bolt", SpellDef.Target.SINGLE_ENEMY, 10, 3), 0)
	assert_eq(mage.sp, 10, "未扣 SP")
	assert_true(cs.is_party_turn(), "未消耗回合")
	assert_gt(ev.size(), 0, "有提示訊息")

func test_insufficient_sp_rejected():
	var mage := _char("Mage", 50, 1, 50, 50)
	mage.known_spells = ["bolt"]
	var cs := CombatSystem.new(_party([mage]), _monsters([_monster("M", 100, 1)]), _rng(1))
	cs.party_cast(_damage("bolt", SpellDef.Target.SINGLE_ENEMY, 10, 3), 0)
	assert_eq(mage.sp, 1, "SP 不足 → 不扣")
	assert_true(cs.is_party_turn())

func test_resistance_modifies_spell_damage():
	var seed := 21
	var c1 := _char("M", 50, 10, 50, 50); c1.known_spells = ["fb"]
	var neutral := _monster("N", 300, 1)
	var cs1 := CombatSystem.new(_party([c1]), _monsters([neutral]), _rng(seed))
	cs1.party_cast(_damage("fb", SpellDef.Target.SINGLE_ENEMY, 20, 2, SpellDef.Element.FIRE), 0)
	var dmg_neutral := 300 - neutral.hp
	var c2 := _char("M", 50, 10, 50, 50); c2.known_spells = ["fb"]
	var weak := _monster("W", 300, 1); weak.resistances = { SpellDef.Element.FIRE: -50 }
	var cs2 := CombatSystem.new(_party([c2]), _monsters([weak]), _rng(seed))
	cs2.party_cast(_damage("fb", SpellDef.Target.SINGLE_ENEMY, 20, 2, SpellDef.Element.FIRE), 0)
	var dmg_weak := 300 - weak.hp
	assert_gt(dmg_weak, dmg_neutral, "負抗性（被克制）吃更多傷")
