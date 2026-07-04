extends GutTest

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

func test_affix_count_bounds():
	assert_eq(Quality.affix_count(Quality.Q.COMMON, _rng(1)), 0)
	assert_eq(Quality.affix_count(Quality.Q.FINE, _rng(1)), 1)
	var rare := Quality.affix_count(Quality.Q.RARE, _rng(7))
	assert_true(rare >= 2 and rare <= 3, "rare 詞綴數 2~3")
	var leg := Quality.affix_count(Quality.Q.LEGENDARY, _rng(7))
	assert_true(leg >= 4 and leg <= 5, "legendary 詞綴數 4~5")

func test_meta():
	assert_eq(Quality.display_name(Quality.Q.RARE), "稀有")
	assert_eq(Quality.id(Quality.Q.LEGENDARY), "legendary")
	assert_eq(Quality.from_id("fine"), Quality.Q.FINE)
	assert_almost_eq(Quality.value_mult(Quality.Q.LEGENDARY), 10.0, 0.001)
