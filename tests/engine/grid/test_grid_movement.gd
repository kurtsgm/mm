extends GutTest

# 3x3 全可走地圖，玩家站中央 (1,1)，面向 NORTH。
func _open_grid() -> GridData:
	return GridData.new(3, 3)

func test_forward_moves_along_facing():
	var grid := _open_grid()
	var pos := Vector2i(1, 1)
	# 面向 NORTH：前進 -> y 減一
	var out := GridMovement.resolve(grid, pos, GridDirection.Dir.NORTH, GridMovement.Move.FORWARD)
	assert_eq(out, Vector2i(1, 0))

func test_backward_moves_opposite_facing():
	var grid := _open_grid()
	var out := GridMovement.resolve(grid, Vector2i(1, 1), GridDirection.Dir.NORTH, GridMovement.Move.BACKWARD)
	assert_eq(out, Vector2i(1, 2))

func test_strafe_left_and_right():
	var grid := _open_grid()
	# 面向 NORTH：左平移 -> 朝 WEST -> x 減一
	var left := GridMovement.resolve(grid, Vector2i(1, 1), GridDirection.Dir.NORTH, GridMovement.Move.STRAFE_LEFT)
	assert_eq(left, Vector2i(0, 1))
	# 面向 NORTH：右平移 -> 朝 EAST -> x 加一
	var right := GridMovement.resolve(grid, Vector2i(1, 1), GridDirection.Dir.NORTH, GridMovement.Move.STRAFE_RIGHT)
	assert_eq(right, Vector2i(2, 1))

func test_blocked_by_wall_stays_put():
	var grid := _open_grid()
	grid.set_solid(Vector2i(1, 0), true)  # 中央正北放牆
	var out := GridMovement.resolve(grid, Vector2i(1, 1), GridDirection.Dir.NORTH, GridMovement.Move.FORWARD)
	assert_eq(out, Vector2i(1, 1), "撞牆應留在原地")

func test_blocked_by_bounds_stays_put():
	var grid := _open_grid()
	# 站在最北排 (1,0) 面向 NORTH 前進 -> 界外 -> 留原地
	var out := GridMovement.resolve(grid, Vector2i(1, 0), GridDirection.Dir.NORTH, GridMovement.Move.FORWARD)
	assert_eq(out, Vector2i(1, 0))
