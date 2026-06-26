extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

func _gs() -> Node:
	var gs = GameStateScript.new()
	add_child_autofree(gs)
	return gs

func test_flags_set_clear_has():
	var gs = _gs()
	assert_false(gs.has_flag("seen"))
	gs.set_flag("seen")
	assert_true(gs.has_flag("seen"))
	gs.clear_flag("seen")
	assert_false(gs.has_flag("seen"))

func test_scene_triggered_per_map():
	var gs = _gs()
	assert_false(gs.is_scene_triggered("town_oak", Vector2i(1, 3)))
	gs.mark_scene_triggered("town_oak", Vector2i(1, 3))
	assert_true(gs.is_scene_triggered("town_oak", Vector2i(1, 3)))
	assert_false(gs.is_scene_triggered("level01", Vector2i(1, 3)))

func test_mark_scene_idempotent():
	var gs = _gs()
	gs.mark_scene_triggered("town_oak", Vector2i(1, 3))
	gs.mark_scene_triggered("town_oak", Vector2i(1, 3))
	assert_eq(gs.triggered_for("town_oak").size(), 1)

func test_triggered_for_unknown_map_empty():
	assert_eq(_gs().triggered_for("nope"), [])
