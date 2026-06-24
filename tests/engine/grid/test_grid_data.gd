extends GutTest

func test_new_grid_is_all_walkable():
	var grid := GridData.new(3, 3)
	assert_eq(grid.width, 3)
	assert_eq(grid.height, 3)
	assert_true(grid.is_walkable(Vector2i(0, 0)))
	assert_true(grid.is_walkable(Vector2i(2, 2)))

func test_out_of_bounds_is_not_walkable_and_is_solid():
	var grid := GridData.new(3, 3)
	assert_false(grid.in_bounds(Vector2i(-1, 0)))
	assert_false(grid.in_bounds(Vector2i(3, 0)))
	assert_false(grid.is_walkable(Vector2i(-1, 0)))
	assert_true(grid.is_solid(Vector2i(3, 3)))

func test_set_solid_blocks_cell():
	var grid := GridData.new(3, 3)
	grid.set_solid(Vector2i(1, 1), true)
	assert_true(grid.is_solid(Vector2i(1, 1)))
	assert_false(grid.is_walkable(Vector2i(1, 1)))
	grid.set_solid(Vector2i(1, 1), false)
	assert_true(grid.is_walkable(Vector2i(1, 1)))
