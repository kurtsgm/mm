extends GutTest

func test_defaults_to_ok_alive_conscious():
	var c := Character.new()
	assert_eq(c.condition, Character.Condition.OK)
	assert_true(c.is_alive())
	assert_true(c.is_conscious())

func test_unconscious_is_alive_but_not_conscious():
	var c := Character.new()
	c.condition = Character.Condition.UNCONSCIOUS
	assert_true(c.is_alive())
	assert_false(c.is_conscious())

func test_dead_is_not_alive_not_conscious():
	var c := Character.new()
	c.condition = Character.Condition.DEAD
	assert_false(c.is_alive())
	assert_false(c.is_conscious())

func test_holds_full_stat_block():
	var c := Character.new()
	c.name = "Gerard"
	c.char_class = "Knight"
	c.level = 3
	c.hp = 18
	c.hp_max = 28
	c.sp = 4
	c.sp_max = 8
	c.might = 18
	c.intellect = 7
	c.personality = 9
	c.endurance = 16
	c.speed = 12
	c.accuracy = 14
	c.luck = 10
	assert_eq(c.name, "Gerard")
	assert_eq(c.char_class, "Knight")
	assert_eq(c.level, 3)
	assert_eq(c.hp, 18)
	assert_eq(c.hp_max, 28)
	assert_eq(c.sp, 4)
	assert_eq(c.sp_max, 8)
	assert_eq(c.might, 18)
	assert_eq(c.luck, 10)

func _weapon(attack: int) -> ItemDef:
	var d := ItemDef.new()
	d.category = ItemDef.Category.WEAPON; d.attack = attack
	return d

func _armor(armor: int) -> ItemDef:
	var d := ItemDef.new()
	d.category = ItemDef.Category.ARMOR; d.armor = armor
	return d

func test_attack_power_without_equipment_equals_might():
	var c := Character.new()
	c.might = 15
	assert_eq(c.attack_power(), 15)
	assert_eq(c.armor_value(), 0)

func test_attack_power_adds_weapon_attack():
	var c := Character.new()
	c.might = 15
	c.equipment.equip(_weapon(6))
	assert_eq(c.attack_power(), 21)

func test_armor_value_sums_equipped_armor():
	var c := Character.new()
	c.equipment.equip(_armor(3))
	assert_eq(c.armor_value(), 3)

func test_each_character_has_independent_equipment():
	var a := Character.new()
	var b := Character.new()
	a.equipment.equip(_weapon(6))
	assert_eq(a.equipment.total_attack(), 6)
	assert_eq(b.equipment.total_attack(), 0)   # 每實例獨立，不共用

func test_known_spells_default_empty():
	var c := Character.new()
	assert_eq(c.known_spells.size(), 0)

func test_statuses_default_empty():
	var c := Character.new()
	assert_eq(c.statuses.size(), 0)

func test_attack_buff_raises_attack_power():
	var c := Character.new(); c.might = 10
	assert_eq(c.attack_power(), 10)
	c.statuses.append(StatusEffect.new(StatusEffect.Stat.ATTACK, 5, 2))
	assert_eq(c.attack_power(), 15)

func test_armor_buff_raises_armor_value():
	var c := Character.new()
	assert_eq(c.armor_value(), 0)
	c.statuses.append(StatusEffect.new(StatusEffect.Stat.ARMOR, 4, 2))
	assert_eq(c.armor_value(), 4)

func test_effective_accuracy_includes_status():
	var c := Character.new(); c.accuracy = 10
	assert_eq(c.effective_accuracy(), 10)
	c.statuses.append(StatusEffect.new(StatusEffect.Stat.ACCURACY, 3, 2))
	assert_eq(c.effective_accuracy(), 13)

func test_status_and_equipment_stack_on_attack():
	var c := Character.new(); c.might = 10
	var w := ItemDef.new(); w.category = ItemDef.Category.WEAPON; w.attack = 6
	c.equipment.equip(w)
	c.statuses.append(StatusEffect.new(StatusEffect.Stat.ATTACK, 2, 2))
	assert_eq(c.attack_power(), 18)   # 10 + 6 + 2

func test_take_damage_reduces_hp():
	var c := Character.new()
	c.hp = 20
	c.hp_max = 20
	c.take_damage(5)
	assert_eq(c.hp, 15)

func test_take_damage_clamps_at_zero():
	var c := Character.new()
	c.hp = 3
	c.hp_max = 20
	c.take_damage(10)
	assert_eq(c.hp, 0)

func test_take_damage_emits_damaged_signal():
	var c := Character.new()
	c.hp = 20
	c.hp_max = 20
	watch_signals(c)
	c.take_damage(7)
	assert_signal_emitted(c, "damaged")

# --- stats_changed：HP/MP/狀態被改動時即時通知 UI（治療術/喝藥水等都走這個 hook） ---

func test_setting_hp_emits_stats_changed():
	var c := Character.new()
	c.hp = 10
	c.hp_max = 28
	watch_signals(c)
	c.hp = 20                       # 模擬治療術回血
	assert_signal_emitted(c, "stats_changed")

func test_setting_sp_emits_stats_changed():
	var c := Character.new()
	c.sp = 4
	c.sp_max = 8
	watch_signals(c)
	c.sp -= 2                       # 模擬施法扣 MP
	assert_signal_emitted(c, "stats_changed")

func test_setting_condition_emits_stats_changed():
	var c := Character.new()
	c.condition = Character.Condition.UNCONSCIOUS
	watch_signals(c)
	c.condition = Character.Condition.OK    # 模擬復活術
	assert_signal_emitted(c, "stats_changed")

func test_setting_hp_to_same_value_does_not_emit():
	var c := Character.new()
	c.hp = 20
	watch_signals(c)
	c.hp = 20                       # 沒變化 → 不應觸發刷新
	assert_signal_not_emitted(c, "stats_changed")

func test_take_damage_emits_stats_changed():
	var c := Character.new()
	c.hp = 20
	c.hp_max = 20
	watch_signals(c)
	c.take_damage(7)
	assert_signal_emitted(c, "stats_changed")

func test_armor_value_includes_endurance_defense():
	var c := Character.new()
	c.endurance = 16   # 16/4 = +4 armor
	assert_eq(c.armor_value(), 4)

func test_higher_endurance_gives_more_armor():
	var low := Character.new()
	low.endurance = 4    # +1
	var high := Character.new()
	high.endurance = 20  # +5
	assert_gt(high.armor_value(), low.armor_value())
