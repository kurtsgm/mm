extends GutTest

func _map(ascii: String) -> MapData:
	return MapImporter.parse(JSON.stringify({"grid": Array(ascii.split("\n"))}))

func test_walls_solid_others_walkable():
	var grid := MapBuilder.to_grid_data(_map("###\n#@#\n###"))
	assert_eq(grid.width, 3)
	assert_eq(grid.height, 3)
	assert_true(grid.is_solid(Vector2i(0, 0)))
	assert_true(grid.is_solid(Vector2i(1, 0)))
	assert_true(grid.is_walkable(Vector2i(1, 1)))

func test_door_and_stairs_are_walkable():
	var grid := MapBuilder.to_grid_data(_map("@D<>"))
	assert_true(grid.is_walkable(Vector2i(0, 0)))  # floor
	assert_true(grid.is_walkable(Vector2i(1, 0)))  # door
	assert_true(grid.is_walkable(Vector2i(2, 0)))  # stairs up
	assert_true(grid.is_walkable(Vector2i(3, 0)))  # stairs down

func test_is_walkable_type():
	assert_false(MapBuilder.is_walkable_type(MapData.TileType.WALL))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.FLOOR))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.DOOR))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.STAIRS_UP))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.STAIRS_DOWN))
