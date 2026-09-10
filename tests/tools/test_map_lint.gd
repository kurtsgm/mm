extends GutTest

func _map(id: String, rows: Array) -> MapData:
	var map := MapImporter.parse(JSON.stringify({"grid": rows}))
	map.map_id = id
	return map

func test_floor_behind_walls_is_not_reachable():
	var map := _map("a", ["#####", "#@#.#", "#####"])
	assert_true(MapLint.path({"a": map}, {"map": "a", "pos": Vector2i(1, 1)}, {"map": "a", "pos": Vector2i(3, 1)}).is_empty())

func test_portal_cannot_be_used_as_corridor_and_one_way_has_no_return():
	var a := _map("a", ["#####", "#@..#", "#####"])
	var b := _map("b", ["#####", "#@..#", "#####"])
	a.links[Vector2i(2, 1)] = {"map": "b", "entry": "start"}
	var maps := {"a": a, "b": b}
	assert_true(MapLint.path(maps, {"map": "a", "pos": a.start_pos}, {"map": "a", "pos": Vector2i(3, 1)}).is_empty())
	assert_false(MapLint.path(maps, {"map": "a", "pos": a.start_pos}, {"map": "b", "pos": b.start_pos}).is_empty())
	assert_true(MapLint.path(maps, {"map": "b", "pos": b.start_pos}, {"map": "a", "pos": a.start_pos}).is_empty())

func test_blocking_npc_can_be_talked_to_but_not_walked_through():
	var a := _map("a", ["#####", "#@..#", "#####"])
	a.quest_givers.append({"pos": Vector2i(2, 1), "blocks": true})
	var maps := {"a": a}
	var source := {"map": "a", "pos": a.start_pos}
	assert_false(MapLint.path(maps, source, {"map": "a", "pos": Vector2i(2, 1)}, true).is_empty())
	assert_true(MapLint.path(maps, source, {"map": "a", "pos": Vector2i(3, 1)}).is_empty())

func test_neighbor_seam_respects_destination_wall():
	var a := _map("a", ["###", "#@.", "###"])
	var b := _map("b", ["###", "#@#", "###"])
	a.neighbors[GridDirection.Dir.EAST] = "b"
	assert_true(MapLint.path({"a": a, "b": b}, {"map": "a", "pos": a.start_pos}, {"map": "b", "pos": b.start_pos}).is_empty())
	assert_false(MapLint._open_seam(a, b, GridDirection.Dir.EAST))

func test_automatic_portal_is_not_a_place_to_stand_and_talk():
	var a := _map("a", ["#####", "#@..#", "#####"])
	var b := _map("b", ["#####", "#@..#", "#####"])
	a.links[Vector2i(2, 1)] = {"map": "b", "entry": "start"}
	a.quest_givers.append({"pos": Vector2i(3, 1), "blocks": true})
	assert_true(MapLint.path({"a": a, "b": b}, {"map": "a", "pos": a.start_pos}, {"map": "a", "pos": Vector2i(3, 1)}, true).is_empty())
