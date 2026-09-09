extends GutTest

const MapManagerScript := preload("res://autoload/map_manager.gd")

func test_load_text_sets_current_map():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.load_text(JSON.stringify({"grid": ["###", "#@#", "###"]}))
	assert_not_null(map)
	assert_eq(mm.current_map, map)
	assert_eq(mm.current_map.width, 3)
	assert_eq(mm.current_map.height, 3)

func test_load_by_id_loads_map_and_sets_id():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.load_by_id("wild_ne")
	assert_not_null(map)
	assert_eq(map.map_id, "wild_ne")
	assert_eq(mm.current_map, map)
	assert_gt(mm.current_map.width, 0)
	assert_true(mm.current_map.has_encounter(Vector2i(5, 5)), "wild_ne (5,5) 應有遭遇")

func test_enter_map_keeps_full_definition():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.enter_map("wild_ne")
	assert_not_null(map)
	assert_eq(map.map_id, "wild_ne")
	assert_true(map.has_encounter(Vector2i(5, 5)), "完整定義不套玩家進度")
	assert_eq(mm.current_map, map)

func test_current_and_neighbor_definitions_agree():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.enter_map("wild_ne")
	assert_eq(map.encounters, mm.peek_map("wild_ne").encounters)

func test_peek_map_loads_without_changing_current():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	mm.load_by_id("wild_nw")            # 先設一個 current
	var before = mm.current_map
	var peeked = mm.peek_map("town_oak")
	assert_not_null(peeked)
	assert_eq(peeked.map_id, "town_oak")
	assert_eq(mm.current_map, before, "peek_map 不應改動 current_map")

func test_peek_map_unknown_returns_null():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	assert_null(mm.peek_map("does_not_exist"))
