extends GutTest

func test_stat_mod_factory():
	var e := StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, -2, 3)
	assert_eq(e.kind, StatusEffect.Kind.STAT_MOD)
	assert_eq(e.stat, StatusEffect.Stat.ATTACK)
	assert_eq(e.amount, -2)
	assert_eq(e.remaining, 3)
	assert_eq(e.potency, 0)

func test_poison_factory():
	var e := StatusCatalog.poison(4, 5)
	assert_eq(e.kind, StatusEffect.Kind.POISON)
	assert_eq(e.potency, 4)
	assert_eq(e.remaining, 5)
	assert_eq(e.stat, -1)

func test_sleep_factory():
	var e := StatusCatalog.sleep(2)
	assert_eq(e.kind, StatusEffect.Kind.SLEEP)
	assert_eq(e.remaining, 2)
	assert_eq(e.potency, 0)

func test_from_data_builds_by_kind():
	var e := StatusCatalog.from_data(StatusEffect.Kind.BURN, -1, 0, 3, 2)
	assert_eq(e.kind, StatusEffect.Kind.BURN)
	assert_eq(e.potency, 3)
	assert_eq(e.remaining, 2)

func test_legacy_ctor_still_stat_mod():
	var e := StatusEffect.new(StatusEffect.Stat.ARMOR, 1, 3)   # 既有呼叫形式
	assert_eq(e.kind, StatusEffect.Kind.STAT_MOD)
	assert_eq(e.stat, StatusEffect.Stat.ARMOR)
	assert_eq(e.amount, 1)
