extends GutTest

func _stat(stat: int, amount: int, rem := 3) -> StatusEffect:
	return StatusCatalog.stat_mod(stat, amount, rem)

func test_stat_total_sums_matching_stat():
	var arr := [_stat(StatusEffect.Stat.ATTACK, 2), _stat(StatusEffect.Stat.ATTACK, -1), _stat(StatusEffect.Stat.ARMOR, 5)]
	assert_eq(StatusRules.stat_total(arr, StatusEffect.Stat.ATTACK), 1)
	assert_eq(StatusRules.stat_total(arr, StatusEffect.Stat.ARMOR), 5)

func test_stat_total_ignores_ailments():
	assert_eq(StatusRules.stat_total([StatusCatalog.poison(4, 3)], StatusEffect.Stat.ATTACK), 0)

func test_turn_damage_sums_dot():
	var arr := [StatusCatalog.poison(4, 3), StatusCatalog.burn(2, 2), StatusCatalog.sleep(1)]
	assert_eq(StatusRules.turn_damage(arr), 6)

func test_prevents_action_sleep_always():
	assert_true(StatusRules.prevents_action([StatusCatalog.sleep(2)], 0.99))

func test_prevents_action_paralysis_by_roll():
	var arr := [StatusCatalog.paralysis(2)]
	assert_true(StatusRules.prevents_action(arr, 0.4))    # < 0.5 → 跳過
	assert_false(StatusRules.prevents_action(arr, 0.6))   # >= 0.5 → 可動

func test_incapacitating_only_for_sleep_paralysis():
	assert_true(StatusRules.incapacitating([StatusCatalog.sleep(1)]))
	assert_true(StatusRules.incapacitating([StatusCatalog.paralysis(1)]))
	assert_false(StatusRules.incapacitating([StatusCatalog.poison(1, 1)]))

func test_prevents_casting_on_silence():
	assert_true(StatusRules.prevents_casting([StatusCatalog.silence(2)]))
	assert_false(StatusRules.prevents_casting([StatusCatalog.poison(1, 1)]))

func test_cleared_on_hit_removes_sleep_only():
	var arr := [StatusCatalog.sleep(2), StatusCatalog.poison(3, 3)]
	var out := StatusRules.cleared_on_hit(arr)
	assert_eq(out.size(), 1)
	assert_eq(out[0].kind, StatusEffect.Kind.POISON)

func test_persists_overworld_poison_only():
	assert_true(StatusRules.persists_overworld(StatusCatalog.poison(1, 1)))
	assert_false(StatusRules.persists_overworld(StatusCatalog.burn(1, 1)))
	assert_false(StatusRules.persists_overworld(StatusCatalog.sleep(1)))

func test_keep_persisting_filters():
	var arr := [StatusCatalog.poison(2, 3), StatusCatalog.sleep(1), StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, 1, 2)]
	var kept := StatusRules.keep_persisting(arr)
	assert_eq(kept.size(), 1)
	assert_eq(kept[0].kind, StatusEffect.Kind.POISON)

func test_label_stat_mod_and_ailments():
	assert_eq(StatusRules.label(StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, 2, 3)), "↑ATK")
	assert_eq(StatusRules.label(StatusCatalog.stat_mod(StatusEffect.Stat.ARMOR, -1, 3)), "↓DEF")
	assert_eq(StatusRules.label(StatusCatalog.poison(2, 3)), "毒")
	assert_eq(StatusRules.label(StatusCatalog.sleep(2)), "睡")
