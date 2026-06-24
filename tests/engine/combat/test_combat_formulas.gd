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
