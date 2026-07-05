extends GutTest

const MapManagerScript := preload("res://autoload/map_manager.gd")

func _load(id: String) -> MapData:
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	return mm.load_by_id(id)

func test_wilderness_2x2_neighbors_symmetric():
	var nw := _load("wild_nw")
	var ne := _load("wild_ne")
	var sw := _load("wild_sw")
	var se := _load("wild_se")
	assert_eq(nw.get_neighbor(GridDirection.Dir.EAST), "wild_ne")
	assert_eq(ne.get_neighbor(GridDirection.Dir.WEST), "wild_nw")
	assert_eq(nw.get_neighbor(GridDirection.Dir.SOUTH), "wild_sw")
	assert_eq(sw.get_neighbor(GridDirection.Dir.NORTH), "wild_nw")
	assert_eq(ne.get_neighbor(GridDirection.Dir.SOUTH), "wild_se")
	assert_eq(se.get_neighbor(GridDirection.Dir.NORTH), "wild_ne")
	assert_eq(sw.get_neighbor(GridDirection.Dir.EAST), "wild_se")
	assert_eq(se.get_neighbor(GridDirection.Dir.WEST), "wild_sw")

func test_all_content_maps_are_local_size():
	var dir := DirAccess.open("res://content/maps")
	assert_not_null(dir, "content/maps 目錄應存在")
	dir.list_dir_begin()
	var checked := 0
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var m := _load(fname.get_basename())
			assert_not_null(m, "%s 應可載入" % fname)
			assert_eq(m.width, MapData.LOCAL_SIZE, "%s width 應為 LOCAL_SIZE" % fname)
			assert_eq(m.height, MapData.LOCAL_SIZE, "%s height 應為 LOCAL_SIZE" % fname)
			checked += 1
		fname = dir.get_next()
	dir.list_dir_end()
	assert_gt(checked, 0, "至少要檢到一張地圖")

func test_town_link_roundtrip():
	var nw := _load("wild_nw")
	assert_eq(nw.get_link(Vector2i(9, 9)), {"map": "town_oak", "entry": "gate"})
	assert_true(nw.has_entry("from_town"))
	assert_eq(nw.get_entry("from_town"), {"pos": Vector2i(7, 9), "facing": GridDirection.Dir.NORTH})
	var town := _load("town_oak")
	assert_eq(town.get_entry("gate"), {"pos": Vector2i(7, 10), "facing": GridDirection.Dir.NORTH})
	assert_eq(town.get_link(Vector2i(7, 11)), {"map": "wild_nw", "entry": "from_town"})

func test_town_oak_uses_town_theme():
	assert_eq(_load("town_oak").theme_id, "town")

func test_wilderness_maps_use_grassland_theme():
	for id in ["wild_nw", "wild_ne", "wild_sw", "wild_se"]:
		assert_eq(_load(id).theme_id, "grassland", "%s 應為 grassland 主題" % id)

func test_wild_nw_has_town_decoration():
	var nw := _load("wild_nw")
	assert_eq(nw.decorations.size(), 1)
	assert_eq(nw.decorations[0]["pos"], Vector2i(9, 9))
	assert_eq(nw.decorations[0]["model"], "town_oak_ext")

func test_wild_ne_has_wandering_merchant():
	var ne := _load("wild_ne")
	assert_true(ne.has_vendor(Vector2i(7, 7)), "流浪商人在 (7,7)")
	assert_eq(ne.get_vendor(Vector2i(7, 7))["id"], "wandering_merchant")

func _building_by_id(town: MapData, id: String) -> Dictionary:
	for b in town.buildings:
		if b["id"] == id:
			return b
	return {}

func test_town_oak_has_five_shop_buildings_and_well():
	var town := _load("town_oak")
	# 五間機能建築 + 中央水井
	for id in ["oak_smithy", "oak_temple", "oak_mage", "oak_general_store", "oak_inn", "oak_well"]:
		assert_false(_building_by_id(town, id).is_empty(), "%s 建築應存在" % id)

func test_town_buildings_door_is_walkable_and_links_interior():
	var town := _load("town_oak")
	# 每間店的門那格 = 可走 + 連到自己的室內地圖；衍生回程入口存在
	var cases := {
		"oak_smithy": {"door": Vector2i(5, 5), "interior": "int_oak_smithy"},
		"oak_temple": {"door": Vector2i(8, 5), "interior": "int_oak_temple"},
		"oak_mage": {"door": Vector2i(10, 5), "interior": "int_oak_mage"},
		"oak_general_store": {"door": Vector2i(5, 8), "interior": "int_oak_general"},
		"oak_inn": {"door": Vector2i(10, 8), "interior": "int_oak_inn"},
	}
	for id in cases:
		var door: Vector2i = cases[id]["door"]
		assert_ne(town.get_tile(door), MapData.TileType.WALL, "%s 門那格要可走" % id)
		assert_true(town.has_link(door), "%s 門那格要有 link" % id)
		assert_eq(town.get_link(door)["map"], cases[id]["interior"], "%s 門連到室內" % id)
		assert_true(town.has_entry(id + "_out"), "%s 應有回程入口 %s_out" % [id, id])

func test_town_building_footprint_tiles_are_walls():
	var town := _load("town_oak")
	# 鐵匠舖 [4,4,2,2] 除門 (5,5) 外都是牆
	assert_eq(town.get_tile(Vector2i(4, 4)), MapData.TileType.WALL)
	assert_eq(town.get_tile(Vector2i(5, 4)), MapData.TileType.WALL)
	assert_eq(town.get_tile(Vector2i(4, 5)), MapData.TileType.WALL)
	# 水井 (7,7) = 實心牆（紀念碑）
	assert_eq(town.get_tile(Vector2i(7, 7)), MapData.TileType.WALL)

func test_town_oak_has_questgivers_and_no_combat():
	var town := _load("town_oak")
	assert_true(town.has_quest_giver(Vector2i(6, 10)), "守衛隊長在城門邊")
	assert_eq(town.get_quest_giver(Vector2i(6, 10))["dialogue"], "qg_oak_guard")
	assert_true(town.has_quest_giver(Vector2i(8, 8)), "瑪歌在廣場")
	assert_eq(town.get_quest_giver(Vector2i(8, 8))["dialogue"], "qg_margo")
	assert_eq(town.encounters.size(), 0, "安全城鎮內不該有遭遇")

func test_wild_sw_has_dream_wisp_encounter():
	var sw := _load("wild_sw")
	assert_true(sw.has_encounter(Vector2i(5, 5)), "夢魘妖遭遇在 (5,5)")
	assert_eq(sw.get_encounter(Vector2i(5, 5)), "dw")
	assert_ne(sw.get_encounter_uid(Vector2i(5, 5)), "", "遭遇需有持久 uid")
