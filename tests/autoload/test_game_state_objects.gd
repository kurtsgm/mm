extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

func _gs() -> Node:
	var gs = GameStateScript.new()
	add_child_autofree(gs)
	return gs

func test_mark_and_query_opened():
	var gs = _gs()
	assert_false(gs.is_object_opened("town_oak", Vector2i(1, 1)))
	gs.mark_object_opened("town_oak", Vector2i(1, 1))
	assert_true(gs.is_object_opened("town_oak", Vector2i(1, 1)))

func test_opened_is_per_map():
	var gs = _gs()
	gs.mark_object_opened("town_oak", Vector2i(1, 1))
	assert_false(gs.is_object_opened("level01", Vector2i(1, 1)))

func test_mark_is_idempotent():
	var gs = _gs()
	gs.mark_object_opened("town_oak", Vector2i(1, 1))
	gs.mark_object_opened("town_oak", Vector2i(1, 1))
	assert_eq(gs.opened_for("town_oak").size(), 1)

func test_opened_for_unknown_map_empty():
	var gs = _gs()
	assert_eq(gs.opened_for("nope"), [])
