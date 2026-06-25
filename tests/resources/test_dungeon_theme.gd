extends GutTest

func test_defaults():
	var t := DungeonTheme.new()
	assert_eq(t.theme_id, "")
	assert_null(t.mesh_library)
	assert_eq(t.floor_item, "floor")
	assert_eq(t.item_for_tile, {})
	assert_false(t.has_ceiling)
	assert_eq(t.ceiling_item, "")

func test_fields_assignable():
	var t := DungeonTheme.new()
	t.theme_id = "castle"
	t.item_for_tile = { MapData.TileType.WALL: "wall" }
	t.has_ceiling = true
	t.ceiling_item = "ceiling"
	assert_eq(t.theme_id, "castle")
	assert_eq(t.item_for_tile[MapData.TileType.WALL], "wall")
	assert_true(t.has_ceiling)
	assert_eq(t.ceiling_item, "ceiling")
