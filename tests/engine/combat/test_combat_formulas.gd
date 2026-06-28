extends GutTest

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_hit_chance_monotonic_in_accuracy():
	assert_lt(CombatFormulas.hit_chance(5, 10), CombatFormulas.hit_chance(15, 10))

func test_hit_chance_clamped():
	assert_eq(CombatFormulas.hit_chance(1000, 0), CombatFormulas.HIT_MAX)
	assert_eq(CombatFormulas.hit_chance(0, 1000), CombatFormulas.HIT_MIN)

func test_roll_damage_within_bounds():
	var rng := _rng(42)
	for i in 200:
		var d := CombatFormulas.roll_damage(10, 3, false, rng)  # base = 7
		assert_between(d, 7, 14)

func test_roll_damage_floor_at_one_when_armor_exceeds_might():
	var rng := _rng(7)
	for i in 50:
		var d := CombatFormulas.roll_damage(2, 10, false, rng)  # base = max(1, -8) = 1
		assert_between(d, 1, 2)

func test_roll_damage_defending_reduces_total():
	var rng := _rng(99)
	var total_norm := 0
	var total_def := 0
	for i in 500:
		total_norm += CombatFormulas.roll_damage(20, 0, false, rng)
		total_def += CombatFormulas.roll_damage(20, 0, true, rng)
	assert_lt(total_def, total_norm)

func test_roll_hit_high_chance_mostly_true():
	var rng := _rng(123)
	var trues := 0
	for i in 1000:
		if CombatFormulas.roll_hit(1000, 0, rng):
			trues += 1
	assert_gt(trues, 850)

func test_roll_hit_low_chance_mostly_false():
	var rng := _rng(123)
	var trues := 0
	for i in 1000:
		if CombatFormulas.roll_hit(0, 1000, rng):
			trues += 1
	assert_lt(trues, 150)

func test_roll_spell_damage_within_range():
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	for i in 30:
		var d := CombatFormulas.roll_spell_damage(10, rng)
		assert_true(d >= 10 and d <= 15, "base 10 → 10..15，實得 %d" % d)

func test_roll_spell_damage_min_base():
	var rng := RandomNumberGenerator.new(); rng.seed = 2
	assert_true(CombatFormulas.roll_spell_damage(0, rng) >= 1)

func test_defense_from_endurance_integer_divide():
	assert_eq(CombatFormulas.defense_from_endurance(18), 4)   # 18/4 = 4
	assert_eq(CombatFormulas.defense_from_endurance(8), 2)    # 8/4 = 2
	assert_eq(CombatFormulas.defense_from_endurance(0), 0)
	assert_eq(CombatFormulas.defense_from_endurance(3), 0)    # below one tier

func test_crit_chance_scales_and_clamps():
	assert_eq(CombatFormulas.crit_chance(0), 0)
	assert_eq(CombatFormulas.crit_chance(10), 10)
	assert_eq(CombatFormulas.crit_chance(1000), CombatFormulas.CRIT_CAP)  # capped
	assert_eq(CombatFormulas.crit_chance(-5), 0)                          # never negative

func test_roll_crit_high_luck_mostly_true():
	var rng := _rng(321)
	var trues := 0
	for i in 1000:
		if CombatFormulas.roll_crit(50, rng):   # cap = 50%
			trues += 1
	assert_between(trues, 400, 600)

func test_roll_crit_zero_luck_never_true():
	var rng := _rng(321)
	for i in 200:
		assert_false(CombatFormulas.roll_crit(0, rng))
