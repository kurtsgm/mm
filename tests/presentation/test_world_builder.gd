extends GutTest

func _map(text: String) -> MapData:
	return MapAsciiImporter.parse(text)

func _wb() -> WorldBuilder:
	var wb := WorldBuilder.new()
	add_child_autofree(wb)
	return wb

func test_wall_gets_feature_floor_cell_gets_floor():
	var wb := _wb()
	wb.build(_map("###\n#@#\n###"))
	var lib := ThemeCatalog.get_theme("default").mesh_library
	var floor_id := lib.find_item_by_name("floor")
	var wall_id := lib.find_item_by_name("wall")
	var fgrid: GridMap = wb.get_node("FloorGrid")
	var feat: GridMap = wb.get_node("FeatureGrid")
	# 中央 (1,1) 是地板：FloorGrid 有 floor、FeatureGrid 無特徵
	assert_eq(fgrid.get_cell_item(Vector3i(1, 0, 1)), floor_id)
	assert_eq(feat.get_cell_item(Vector3i(1, 0, 1)), GridMap.INVALID_CELL_ITEM)
	# 角落 (0,0) 是牆：FeatureGrid=wall、FloorGrid 無地板
	assert_eq(feat.get_cell_item(Vector3i(0, 0, 0)), wall_id)
	assert_eq(fgrid.get_cell_item(Vector3i(0, 0, 0)), GridMap.INVALID_CELL_ITEM)

func test_door_and_stairs_get_floor_and_feature():
	var wb := _wb()
	wb.build(_map("@D<>"))  # (0,0)floor (1,0)door (2,0)up (3,0)down
	var lib := ThemeCatalog.get_theme("default").mesh_library
	var fgrid: GridMap = wb.get_node("FloorGrid")
	var feat: GridMap = wb.get_node("FeatureGrid")
	var floor_id := lib.find_item_by_name("floor")
	for x in [0, 1, 2, 3]:
		assert_eq(fgrid.get_cell_item(Vector3i(x, 0, 0)), floor_id, "x=%d 應有地板" % x)
	assert_eq(feat.get_cell_item(Vector3i(1, 0, 0)), lib.find_item_by_name("door"))
	assert_eq(feat.get_cell_item(Vector3i(2, 0, 0)), lib.find_item_by_name("stairs_up"))
	assert_eq(feat.get_cell_item(Vector3i(3, 0, 0)), lib.find_item_by_name("stairs_down"))
	assert_eq(feat.get_cell_item(Vector3i(0, 0, 0)), GridMap.INVALID_CELL_ITEM, "純地板格無特徵")

func test_rebuild_clears_previous_cells():
	var wb := _wb()
	wb.build(_map("###\n#@#\n###"))
	var feat: GridMap = wb.get_node("FeatureGrid")
	var wall_id := ThemeCatalog.get_theme("default").mesh_library.find_item_by_name("wall")
	assert_eq(feat.get_cell_item(Vector3i(0, 0, 0)), wall_id)
	wb.build(_map("...\n.@.\n..."))  # 全地板
	assert_eq(feat.get_cell_item(Vector3i(0, 0, 0)), GridMap.INVALID_CELL_ITEM, "rebuild 應清掉舊牆")

func test_ceiling_placed_when_theme_has_ceiling():
	var wb := _wb()
	var theme := _theme_with_ceiling()
	wb.build(_map("###\n#@#\n###"), theme)
	var feat: GridMap = wb.get_node("FeatureGrid")
	var ceil_id := theme.mesh_library.find_item_by_name("ceiling")
	# 可走格 (1,1) 上方 y=1 應有天花板；牆格 (0,0) 上方無
	assert_eq(feat.get_cell_item(Vector3i(1, 1, 1)), ceil_id)
	assert_eq(feat.get_cell_item(Vector3i(0, 1, 0)), GridMap.INVALID_CELL_ITEM)

func _theme_with_ceiling() -> DungeonTheme:
	var t := DungeonTheme.new()
	t.theme_id = "test_ceiling"
	t.floor_item = "floor"
	t.item_for_tile = { MapData.TileType.WALL: "wall" }
	t.has_ceiling = true
	t.ceiling_item = "ceiling"
	var lib := MeshLibrary.new()
	for name in ["floor", "wall", "ceiling"]:
		var id := lib.get_last_unused_item_id()
		lib.create_item(id)
		lib.set_item_name(id, name)
		lib.set_item_mesh(id, BoxMesh.new())
	t.mesh_library = lib
	return t
