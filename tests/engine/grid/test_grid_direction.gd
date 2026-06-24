extends GutTest

func test_turn_right_cycles_clockwise():
	assert_eq(GridDirection.turn_right(GridDirection.Dir.NORTH), GridDirection.Dir.EAST)
	assert_eq(GridDirection.turn_right(GridDirection.Dir.EAST), GridDirection.Dir.SOUTH)
	assert_eq(GridDirection.turn_right(GridDirection.Dir.SOUTH), GridDirection.Dir.WEST)
	assert_eq(GridDirection.turn_right(GridDirection.Dir.WEST), GridDirection.Dir.NORTH)

func test_turn_left_cycles_counterclockwise():
	assert_eq(GridDirection.turn_left(GridDirection.Dir.NORTH), GridDirection.Dir.WEST)
	assert_eq(GridDirection.turn_left(GridDirection.Dir.WEST), GridDirection.Dir.SOUTH)
	assert_eq(GridDirection.turn_left(GridDirection.Dir.SOUTH), GridDirection.Dir.EAST)
	assert_eq(GridDirection.turn_left(GridDirection.Dir.EAST), GridDirection.Dir.NORTH)

func test_opposite():
	assert_eq(GridDirection.opposite(GridDirection.Dir.NORTH), GridDirection.Dir.SOUTH)
	assert_eq(GridDirection.opposite(GridDirection.Dir.EAST), GridDirection.Dir.WEST)

func test_to_vector():
	assert_eq(GridDirection.to_vector(GridDirection.Dir.NORTH), Vector2i(0, -1))
	assert_eq(GridDirection.to_vector(GridDirection.Dir.EAST), Vector2i(1, 0))
	assert_eq(GridDirection.to_vector(GridDirection.Dir.SOUTH), Vector2i(0, 1))
	assert_eq(GridDirection.to_vector(GridDirection.Dir.WEST), Vector2i(-1, 0))
