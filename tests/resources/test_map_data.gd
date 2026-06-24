extends GutTest

func test_dimensions_and_get_tile():
	var map := MapData.new()
	map.width = 3
	map.height = 2
	map.tiles = PackedInt32Array([
		MapData.TileType.WALL, MapData.TileType.FLOOR, MapData.TileType.DOOR,
		MapData.TileType.FLOOR, MapData.TileType.STAIRS_UP, MapData.TileType.WALL,
	])
	assert_eq(map.width, 3)
	assert_eq(map.height, 2)
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(1, 0)), MapData.TileType.FLOOR)
	assert_eq(map.get_tile(Vector2i(2, 0)), MapData.TileType.DOOR)
	assert_eq(map.get_tile(Vector2i(1, 1)), MapData.TileType.STAIRS_UP)

func test_out_of_bounds_is_wall():
	var map := MapData.new()
	map.width = 2
	map.height = 2
	map.tiles = PackedInt32Array([0, 0, 0, 0])  # 全 FLOOR
	assert_eq(map.get_tile(Vector2i(-1, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(2, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(0, 2)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.FLOOR)

func test_encounters_accessors():
	var map := MapData.new()
	map.encounters = { Vector2i(2, 1): "g" }
	assert_true(map.has_encounter(Vector2i(2, 1)))
	assert_eq(map.get_encounter(Vector2i(2, 1)), "g")
	assert_false(map.has_encounter(Vector2i(0, 0)))
	assert_eq(map.get_encounter(Vector2i(0, 0)), "")
	map.clear_encounter(Vector2i(2, 1))
	assert_false(map.has_encounter(Vector2i(2, 1)))
