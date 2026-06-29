extends GutTest

const SaveSystemScript := preload("res://autoload/save_system.gd")
const GameStateScript := preload("res://autoload/game_state.gd")
const MapManagerScript := preload("res://autoload/map_manager.gd")

func _sys() -> Node:
	var s = SaveSystemScript.new()
	add_child_autofree(s)
	return s

func _gs() -> Node:
	var g = GameStateScript.new()
	add_child_autofree(g)
	return g

func _mm() -> Node:
	var m = MapManagerScript.new()
	add_child_autofree(m)
	return m

func test_capture_from_reads_game_state():
	var ss = _sys()
	var gs = _gs()
	gs.gold = 99
	gs.current_map_id = "wild_ne"
	gs.player_pos = Vector2i(4, 7)
	gs.player_facing = GridDirection.Dir.SOUTH
	gs.mark_encounter_cleared("wild_ne", Vector2i(1, 1))
	var data = ss.capture_from(gs)
	assert_eq(data.gold, 99)
	assert_eq(data.map_id, "wild_ne")
	assert_eq(data.player_pos, Vector2i(4, 7))
	assert_eq(data.player_facing, GridDirection.Dir.SOUTH)
	assert_eq(data.party, gs.party)
	assert_true(data.cleared_encounters["wild_ne"].has(Vector2i(1, 1)))

func test_apply_to_restores_state_and_clears_encounters():
	var ss = _sys()
	var gs = _gs()
	var mm = _mm()
	# 先載一次 wild_ne 取得一個真實遭遇格座標
	mm.load_by_id("wild_ne")
	var enc: Vector2i = mm.current_map.encounters.keys()[0]
	var data := SaveData.new()
	data.gold = 50
	data.map_id = "wild_ne"
	data.player_pos = Vector2i(1, 1)
	data.player_facing = GridDirection.Dir.WEST
	data.party = Party.create_default()
	data.cleared_encounters = {"wild_ne": [enc]}
	ss.apply_to(data, gs, mm)
	assert_eq(gs.gold, 50)
	assert_eq(gs.current_map_id, "wild_ne")
	assert_eq(gs.player_pos, Vector2i(1, 1))
	assert_eq(gs.player_facing, GridDirection.Dir.WEST)
	assert_eq(mm.current_map.map_id, "wild_ne")
	assert_false(mm.current_map.has_encounter(enc), "已清遭遇應被抹除")

func test_capture_from_reads_explored():
	var ss = _sys()
	var gs = _gs()
	gs.mark_explored("wild_ne", Vector2i(2, 2), 5, 5)
	var data = ss.capture_from(gs)
	assert_true(data.explored["wild_ne"].has(Vector2i(2, 2)))

func test_apply_to_restores_explored():
	var ss = _sys()
	var gs = _gs()
	var mm = _mm()
	mm.load_by_id("wild_ne")
	var data := SaveData.new()
	data.map_id = "wild_ne"
	data.party = Party.create_default()
	data.explored = {"wild_ne": {Vector2i(3, 3): true}}
	ss.apply_to(data, gs, mm)
	assert_true(gs.explored["wild_ne"].has(Vector2i(3, 3)))

func test_capture_apply_carries_opened_objects():
	var gs := GameStateScript.new()
	add_child_autofree(gs)
	gs.current_map_id = "town_oak"  # apply_to 會 enter_map(map_id)，需給真實地圖避免無關 assert
	gs.opened_objects = {"town_oak": [Vector2i(1, 1)]}
	var data := SaveSystem.capture_from(gs)
	assert_eq(data.opened_objects, {"town_oak": [Vector2i(1, 1)]})
	var gs2 := GameStateScript.new()
	add_child_autofree(gs2)
	SaveSystem.apply_to(data, gs2, MapManager)
	assert_eq(gs2.opened_objects, {"town_oak": [Vector2i(1, 1)]})
