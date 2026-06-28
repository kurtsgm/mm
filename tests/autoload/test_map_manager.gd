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

func test_load_by_id_loads_level01_and_sets_map_id():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.load_by_id("level01")
	assert_not_null(map)
	assert_eq(map.map_id, "level01")
	assert_eq(mm.current_map, map)
	assert_gt(mm.current_map.width, 0)
	assert_true(mm.current_map.has_encounter(Vector2i(2, 2)), "level01 (2,2) 應有遭遇")

func test_enter_map_clears_given_encounters():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.enter_map("level01", [Vector2i(2, 2)])
	assert_not_null(map)
	assert_eq(map.map_id, "level01")
	assert_false(map.has_encounter(Vector2i(2, 2)), "已清座標不應再有遭遇")
	assert_eq(mm.current_map, map)

func test_enter_map_without_cleared_keeps_encounters():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.enter_map("level01")
	assert_true(map.has_encounter(Vector2i(2, 2)))

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
