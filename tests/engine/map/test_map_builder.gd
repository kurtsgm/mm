extends GutTest

func test_is_walkable_type():
	assert_false(MapBuilder.is_walkable_type(MapData.TileType.WALL))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.FLOOR))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.DOOR))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.STAIRS_UP))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.STAIRS_DOWN))
