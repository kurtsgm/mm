extends GutTest

func test_default_theme_has_core_items():
	var t := ThemeCatalog.get_theme("default")
	assert_not_null(t)
	assert_eq(t.theme_id, "default")
	assert_eq(t.floor_item, "floor")
	assert_false(t.has_ceiling)
	assert_not_null(t.mesh_library)
	for name in ["floor", "wall", "door", "stairs_up", "stairs_down"]:
		assert_ne(t.mesh_library.find_item_by_name(name), -1, "default lib 應有 item: %s" % name)

func test_item_for_tile_maps_features():
	var t := ThemeCatalog.get_theme("default")
	assert_eq(t.item_for_tile[MapData.TileType.WALL], "wall")
	assert_eq(t.item_for_tile[MapData.TileType.DOOR], "door")
	assert_eq(t.item_for_tile[MapData.TileType.STAIRS_UP], "stairs_up")
	assert_eq(t.item_for_tile[MapData.TileType.STAIRS_DOWN], "stairs_down")
	assert_false(t.item_for_tile.has(MapData.TileType.FLOOR), "地板走 floor_item，不在 item_for_tile")

func test_unknown_id_falls_back_to_default():
	var t := ThemeCatalog.get_theme("does_not_exist")
	assert_not_null(t)
	assert_eq(t.theme_id, "default")

func test_has_theme_and_all_ids_include_default():
	assert_true(ThemeCatalog.has_theme("default"))
	assert_true(ThemeCatalog.all_ids().has("default"))
