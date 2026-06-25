extends GutTest

func test_neutral_unchanged():
	assert_eq(Resistance.apply(100, 0), 100)

func test_positive_resistance_reduces():
	assert_eq(Resistance.apply(100, 50), 50)

func test_negative_resistance_increases():
	# 負抗性 = 被克制
	assert_eq(Resistance.apply(100, -50), 150)

func test_full_resistance_is_immune():
	assert_eq(Resistance.apply(100, 100), 0)
	assert_eq(Resistance.apply(100, 150), 0)

func test_never_negative():
	assert_eq(Resistance.apply(1, 100), 0)
	assert_true(Resistance.apply(3, 90) >= 0)

func test_floor_rounding():
	# floor(7 * (100-25)/100) = floor(5.25) = 5
	assert_eq(Resistance.apply(7, 25), 5)
