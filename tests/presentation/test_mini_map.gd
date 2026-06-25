extends GutTest

const MiniMapScript := preload("res://presentation/ui/mini_map.gd")

func test_portal_overrides_tile_color():
	# portal 旗標優先於底層 tile
	assert_eq(MiniMapScript.tile_color(MapData.TileType.FLOOR, true), MiniMapScript.COL_PORTAL)
	assert_eq(MiniMapScript.tile_color(MapData.TileType.WALL, true), MiniMapScript.COL_PORTAL)

func test_tile_colors_by_type():
	assert_eq(MiniMapScript.tile_color(MapData.TileType.FLOOR, false), MiniMapScript.COL_FLOOR)
	assert_eq(MiniMapScript.tile_color(MapData.TileType.WALL, false), MiniMapScript.COL_WALL)
	assert_eq(MiniMapScript.tile_color(MapData.TileType.DOOR, false), MiniMapScript.COL_DOOR)
	assert_eq(MiniMapScript.tile_color(MapData.TileType.STAIRS_UP, false), MiniMapScript.COL_STAIRS_UP)
	assert_eq(MiniMapScript.tile_color(MapData.TileType.STAIRS_DOWN, false), MiniMapScript.COL_STAIRS_DOWN)
