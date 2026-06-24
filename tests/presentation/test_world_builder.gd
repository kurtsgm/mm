extends GutTest

func test_test_map_shape():
	var grid := TestMap.build()
	assert_eq(grid.width, 7)
	assert_eq(grid.height, 7)
	# outer ring is solid (sample corners + an edge)
	assert_true(grid.is_solid(Vector2i(0, 0)))
	assert_true(grid.is_solid(Vector2i(6, 6)))
	assert_true(grid.is_solid(Vector2i(3, 0)))
	# interior walls from the brief
	assert_true(grid.is_solid(Vector2i(3, 1)))
	assert_true(grid.is_solid(Vector2i(3, 2)))
	assert_true(grid.is_solid(Vector2i(3, 3)))
	assert_true(grid.is_solid(Vector2i(5, 4)))
	assert_true(grid.is_solid(Vector2i(2, 5)))
	# start cell is walkable and as specified
	assert_eq(TestMap.start_pos(), Vector2i(1, 1))
	assert_true(grid.is_walkable(TestMap.start_pos()))
	assert_eq(TestMap.start_facing(), GridDirection.Dir.NORTH)

func test_world_builder_node_structure():
	var grid := TestMap.build()
	var wb := WorldBuilder.new()
	add_child_autofree(wb)
	wb.build(grid)
	# count solid cells
	var solid := 0
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.is_solid(Vector2i(x, y)):
				solid += 1
	# one floor mesh + one wall mesh per solid cell
	assert_eq(wb.get_child_count(), solid + 1, "expected 1 floor + %d wall meshes" % solid)
	assert_gt(solid, 0, "test map should have walls")
