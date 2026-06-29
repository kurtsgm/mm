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
	assert_eq(nw.get_link(Vector2i(6, 6)), {"map": "town_oak", "entry": "gate"})
	assert_true(nw.has_entry("from_town"))
	assert_eq(nw.get_entry("from_town"), {"pos": Vector2i(4, 6), "facing": GridDirection.Dir.NORTH})
	var town := _load("town_oak")
	assert_eq(town.get_entry("gate"), {"pos": Vector2i(4, 2), "facing": GridDirection.Dir.SOUTH})
	assert_eq(town.get_link(Vector2i(4, 6)), {"map": "wild_nw", "entry": "from_town"})

func test_town_oak_uses_town_theme():
	assert_eq(_load("town_oak").theme_id, "town")

func test_wilderness_maps_use_grassland_theme():
	for id in ["wild_nw", "wild_ne", "wild_sw", "wild_se"]:
		assert_eq(_load(id).theme_id, "grassland", "%s 應為 grassland 主題" % id)

func test_wild_nw_has_town_decoration():
	var nw := _load("wild_nw")
	assert_eq(nw.decorations.size(), 1)
	assert_eq(nw.decorations[0]["pos"], Vector2i(6, 6))
	assert_eq(nw.decorations[0]["model"], "town_oak_ext")

func test_wild_ne_has_wandering_merchant():
	var ne := _load("wild_ne")
	assert_true(ne.has_vendor(Vector2i(4, 4)), "流浪商人在 (4,4)")
	assert_eq(ne.get_vendor(Vector2i(4, 4))["id"], "wandering_merchant")

func test_town_oak_has_demo_chests():
	var town := _load("town_oak")
	assert_true(town.has_object(Vector2i(2, 2)), "普通寶箱在 (2,2)")
	assert_eq(town.get_object(Vector2i(2, 2))["gold"], 50)
	assert_true(town.has_object(Vector2i(6, 2)), "看守寶箱在 (6,2)")
	assert_eq(town.get_object(Vector2i(6, 2))["gold"], 30)
	assert_eq(town.get_object(Vector2i(6, 2))["items"], ["short_sword"])
	assert_true(town.has_encounter(Vector2i(6, 2)), "(6,2) 同格有遭遇（看守怪）")

func test_wild_sw_has_dream_wisp_encounter():
	var sw := _load("wild_sw")
	assert_true(sw.has_encounter(Vector2i(2, 2)), "夢魘妖遭遇在 (2,2)")
	assert_eq(sw.get_encounter(Vector2i(2, 2)), "dw")
	assert_ne(sw.get_encounter_uid(Vector2i(2, 2)), "", "遭遇需有持久 uid")
