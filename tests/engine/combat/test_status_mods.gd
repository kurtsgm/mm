extends GutTest

func test_status_construction():
	var s := StatusEffect.new(StatusEffect.Stat.ARMOR, -2, 3)
	assert_eq(s.stat, StatusEffect.Stat.ARMOR)
	assert_eq(s.amount, -2)
	assert_eq(s.remaining, 3)

func test_sum_empty():
	assert_eq(StatusMods.sum([], StatusEffect.Stat.ATTACK), 0)

func test_sum_single():
	var arr := [StatusEffect.new(StatusEffect.Stat.ATTACK, 5, 2)]
	assert_eq(StatusMods.sum(arr, StatusEffect.Stat.ATTACK), 5)

func test_sum_filters_by_stat():
	var arr := [
		StatusEffect.new(StatusEffect.Stat.ATTACK, 5, 2),
		StatusEffect.new(StatusEffect.Stat.ARMOR, 3, 2),
	]
	assert_eq(StatusMods.sum(arr, StatusEffect.Stat.ATTACK), 5)
	assert_eq(StatusMods.sum(arr, StatusEffect.Stat.ARMOR), 3)
	assert_eq(StatusMods.sum(arr, StatusEffect.Stat.ACCURACY), 0)

func test_sum_accumulates_same_stat():
	var arr := [
		StatusEffect.new(StatusEffect.Stat.ACCURACY, 3, 1),
		StatusEffect.new(StatusEffect.Stat.ACCURACY, 2, 1),
	]
	assert_eq(StatusMods.sum(arr, StatusEffect.Stat.ACCURACY), 5)
