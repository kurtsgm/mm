extends GutTest

func _char(n: String, cls: String, hp: int, hp_max: int, might: int, intellect: int, personality: int, acc: int, speed: int) -> Character:
	var c := Character.new()
	c.name = n; c.char_class = cls
	c.hp = hp; c.hp_max = hp_max
	c.might = might; c.intellect = intellect; c.personality = personality
	c.accuracy = acc; c.speed = speed
	c.condition = Character.Condition.OK
	return c

func _ko(c: Character) -> Character:
	c.hp = 0; c.condition = Character.Condition.UNCONSCIOUS
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

# --- 純 helper ---

func test_lowest_hp_monster_index_picks_min():
	var living := [_monster("A", 10, 1, 1, 1), _monster("B", 3, 1, 1, 1), _monster("C", 7, 1, 1, 1)]
	assert_eq(PartyCombatPolicy.lowest_hp_monster_index(living), 1)

func test_unconscious_ally_index():
	var p := _party([_char("A", "Knight", 10, 10, 1, 1, 1, 1, 1), _ko(_char("B", "Knight", 10, 10, 1, 1, 1, 1, 1))])
	assert_eq(PartyCombatPolicy.unconscious_ally_index(p), 1)
	var healthy := _party([_char("A", "Knight", 10, 10, 1, 1, 1, 1, 1)])
	assert_eq(PartyCombatPolicy.unconscious_ally_index(healthy), -1)

func test_lowest_hurt_ally_below_threshold():
	var p := _party([_char("Full", "Knight", 100, 100, 1, 1, 1, 1, 1), _char("Hurt", "Knight", 30, 100, 1, 1, 1, 1, 1)])
	assert_eq(PartyCombatPolicy.lowest_hurt_ally_index(p, 0.40), 1)   # 30% < 40%

func test_lowest_hurt_ally_none_when_all_healthy():
	var p := _party([_char("A", "Knight", 100, 100, 1, 1, 1, 1, 1), _char("B", "Knight", 80, 100, 1, 1, 1, 1, 1)])
	assert_eq(PartyCombatPolicy.lowest_hurt_ally_index(p, 0.40), -1)

func test_best_damage_spell_single_vs_aoe_by_count():
	# Cassia intellect 12：spark(單體) mag=4+floor(.5*12)=10；flame_wave(AoE) mag=3+floor(.25*12)=6
	var c := _char("Cassia", "Sorcerer", 30, 30, 15, 12, 12, 13, 13)
	c.sp = 10; c.sp_max = 10
	c.known_spells = ["spark", "flame_wave"]
	assert_eq(PartyCombatPolicy.best_damage_spell(c, 1).id, "spark")        # 1 怪：10 vs 6
	assert_eq(PartyCombatPolicy.best_damage_spell(c, 4).id, "flame_wave")   # 4 怪：10 vs 24

func test_best_damage_spell_null_when_sp_too_low():
	var c := _char("Cassia", "Sorcerer", 30, 30, 15, 12, 12, 13, 13)
	c.sp = 1; c.sp_max = 1   # spark 要 2 SP
	c.known_spells = ["spark", "flame_wave"]
	assert_null(PartyCombatPolicy.best_damage_spell(c, 1))

# --- act 整合 ---

func test_act_attacker_focus_fires_lowest_hp_monster():
	var hero := _char("Hero", "Knight", 200, 200, 50, 1, 1, 1000, 50)   # 快、必中、無法術
	var a := _monster("A", 30, 1, 1, 1)
	var b := _monster("B", 5, 1, 1, 1)                                   # 最低血
	# 注：seed 2（非 brief 的 1）。seed 1 首擲 randi(1,100)=98 > 95% 命中率→必 miss，
	# 與本測意圖（集火打死最低血怪）不符；seed 2 首擲 51 命中，斷言不變。
	var cs := CombatSystem.new(_party([hero]), _monsters([a, b]), _rng(2))
	assert_true(cs.is_party_turn())
	PartyCombatPolicy.act(cs)
	assert_false(b.is_alive())   # 集火打死最低血的 b

func test_act_healer_heals_wounded_ally():
	var cleric := _char("Cleric", "Cleric", 30, 30, 5, 12, 12, 13, 50)  # 快、會 heal/revive
	cleric.sp = 20; cleric.sp_max = 20
	cleric.known_spells = ["heal", "revive", "bless"]
	var wounded := _char("Wound", "Knight", 5, 100, 1, 1, 1, 1, 1)      # 5% < 40%
	var mon := _monster("M", 100, 1, 1, 1)                              # 慢、弱
	var cs := CombatSystem.new(_party([cleric, wounded]), _monsters([mon]), _rng(1))
	assert_eq(cs.current_combatant().name, "Cleric")
	var before: int = wounded.hp
	PartyCombatPolicy.act(cs)
	assert_gt(wounded.hp, before)   # 補了血

func test_act_healer_revives_unconscious_ally():
	var cleric := _char("Cleric", "Cleric", 30, 30, 5, 12, 12, 13, 50)
	cleric.sp = 20; cleric.sp_max = 20
	cleric.known_spells = ["heal", "revive", "bless"]
	var down := _ko(_char("Down", "Knight", 0, 100, 1, 1, 1, 1, 1))
	var mon := _monster("M", 100, 1, 1, 1)
	var cs := CombatSystem.new(_party([cleric, down]), _monsters([mon]), _rng(1))
	PartyCombatPolicy.act(cs)
	assert_true(down.is_conscious())   # 復活優先於補血/攻擊
