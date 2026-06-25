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

func test_town_theme_loads_with_core_items():
	var t := ThemeCatalog.get_theme("town")
	assert_not_null(t)
	assert_eq(t.theme_id, "town")
	assert_eq(t.floor_item, "floor")
	assert_false(t.has_ceiling)
	assert_not_null(t.mesh_library)
	for name in ["floor", "wall", "door", "stairs_up", "stairs_down"]:
		assert_ne(t.mesh_library.find_item_by_name(name), -1, "town lib 應有 item: %s" % name)

func test_town_wall_uses_castle_wall_material():
	var t := ThemeCatalog.get_theme("town")
	var wall_id := t.mesh_library.find_item_by_name("wall")
	var mesh := t.mesh_library.get_item_mesh(wall_id)
	assert_not_null(mesh)
	var mat := mesh.surface_get_material(0)
	assert_true(mat is StandardMaterial3D, "城鎮牆應為貼圖材質")
	assert_not_null((mat as StandardMaterial3D).albedo_texture, "城鎮牆應有 albedo 貼圖")

func test_town_registered_in_catalog():
	assert_true(ThemeCatalog.has_theme("town"))
	assert_true(ThemeCatalog.all_ids().has("town"))

func test_grassland_theme_loads_with_core_items():
	var t := ThemeCatalog.get_theme("grassland")
	assert_not_null(t)
	assert_eq(t.theme_id, "grassland")
	assert_eq(t.floor_item, "floor")
	assert_false(t.has_ceiling)
	assert_not_null(t.mesh_library)
	for name in ["floor", "wall", "door", "stairs_up", "stairs_down"]:
		assert_ne(t.mesh_library.find_item_by_name(name), -1, "grassland lib 應有 item: %s" % name)

func test_grassland_floor_uses_grass_material():
	var t := ThemeCatalog.get_theme("grassland")
	var floor_id := t.mesh_library.find_item_by_name("floor")
	var mesh := t.mesh_library.get_item_mesh(floor_id)
	assert_not_null(mesh)
	var mat := mesh.surface_get_material(0)
	assert_true(mat is StandardMaterial3D, "草地地板應為貼圖材質")
	assert_not_null((mat as StandardMaterial3D).albedo_texture, "草地地板應有 albedo 貼圖")

func test_grassland_registered_in_catalog():
	assert_true(ThemeCatalog.has_theme("grassland"))
	assert_true(ThemeCatalog.all_ids().has("grassland"))
