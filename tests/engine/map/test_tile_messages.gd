extends GutTest

func test_special_tiles_have_messages():
	assert_ne(TileMessages.for_tile(MapData.TileType.DOOR), "")
	assert_ne(TileMessages.for_tile(MapData.TileType.STAIRS_UP), "")
	assert_ne(TileMessages.for_tile(MapData.TileType.STAIRS_DOWN), "")

func test_plain_tiles_have_no_message():
	assert_eq(TileMessages.for_tile(MapData.TileType.FLOOR), "")
	assert_eq(TileMessages.for_tile(MapData.TileType.WALL), "")
