extends GutTest

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
