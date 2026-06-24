extends GutTest

func test_cell_to_world_scales_by_cell_size():
	assert_eq(GridGeometry.cell_to_world(Vector2i(0, 0)), Vector3(0, 0, 0))
	assert_eq(GridGeometry.cell_to_world(Vector2i(1, 0)), Vector3(2, 0, 0))
	assert_eq(GridGeometry.cell_to_world(Vector2i(3, 2)), Vector3(6, 0, 4))

func test_facing_to_yaw():
	assert_almost_eq(GridGeometry.facing_to_yaw(GridDirection.Dir.NORTH), 0.0, 0.0001)
	assert_almost_eq(GridGeometry.facing_to_yaw(GridDirection.Dir.EAST), -PI / 2.0, 0.0001)
	assert_almost_eq(GridGeometry.facing_to_yaw(GridDirection.Dir.SOUTH), -PI, 0.0001)
	assert_almost_eq(GridGeometry.facing_to_yaw(GridDirection.Dir.WEST), -3.0 * PI / 2.0, 0.0001)
