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

func test_wilderness_maps_share_dimensions():
	for id in ["wild_nw", "wild_ne", "wild_sw", "wild_se"]:
		var m := _load(id)
		assert_eq(m.width, 5, "%s width" % id)
		assert_eq(m.height, 5, "%s height" % id)

func test_town_link_roundtrip():
	var nw := _load("wild_nw")
	assert_eq(nw.get_link(Vector2i(3, 3)), {"map": "town_oak", "entry": "gate"})
	assert_true(nw.has_entry("from_town"))
	assert_eq(nw.get_entry("from_town"), {"pos": Vector2i(2, 3), "facing": GridDirection.Dir.NORTH})
	var town := _load("town_oak")
	assert_eq(town.get_entry("gate"), {"pos": Vector2i(2, 1), "facing": GridDirection.Dir.SOUTH})
	assert_eq(town.get_link(Vector2i(2, 3)), {"map": "wild_nw", "entry": "from_town"})

func test_town_oak_uses_town_theme():
	assert_eq(_load("town_oak").theme_id, "town")

func test_wilderness_maps_use_grassland_theme():
	for id in ["wild_nw", "wild_ne", "wild_sw", "wild_se"]:
		assert_eq(_load(id).theme_id, "grassland", "%s 應為 grassland 主題" % id)

func test_wild_nw_has_town_decoration():
	var nw := _load("wild_nw")
	assert_eq(nw.decorations.size(), 1)
	assert_eq(nw.decorations[0]["pos"], Vector2i(3, 3))
	assert_eq(nw.decorations[0]["model"], "town_oak_ext")

func test_town_oak_has_demo_chests():
	var town := _load("town_oak")
	assert_true(town.has_object(Vector2i(1, 1)), "普通寶箱在 (1,1)")
	assert_eq(town.get_object(Vector2i(1, 1))["gold"], 50)
	assert_true(town.has_object(Vector2i(3, 1)), "看守寶箱在 (3,1)")
	assert_true(town.has_encounter(Vector2i(3, 1)), "(3,1) 同格有遭遇（看守怪）")
