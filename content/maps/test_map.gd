class_name TestMap
extends Object

# 回傳一張 7x7 地圖：外圈整圈是牆，內部挖幾道牆做出走廊感。
# 玩家起點 (1,1) 保證可走。
static func build() -> GridData:
	var grid := GridData.new(7, 7)
	# 外圈牆
	for x in range(7):
		grid.set_solid(Vector2i(x, 0), true)
		grid.set_solid(Vector2i(x, 6), true)
	for y in range(7):
		grid.set_solid(Vector2i(0, y), true)
		grid.set_solid(Vector2i(6, y), true)
	# 內部幾道牆（留出走廊）
	grid.set_solid(Vector2i(3, 1), true)
	grid.set_solid(Vector2i(3, 2), true)
	grid.set_solid(Vector2i(3, 3), true)
	grid.set_solid(Vector2i(5, 4), true)
	grid.set_solid(Vector2i(2, 5), true)
	return grid

static func start_pos() -> Vector2i:
	return Vector2i(1, 1)

static func start_facing() -> int:
	return GridDirection.Dir.NORTH
