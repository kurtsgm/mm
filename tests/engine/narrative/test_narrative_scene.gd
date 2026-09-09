extends GutTest

const State := preload("res://autoload/game_state.gd")

func _state():
	var state := State.new()
	add_child_autofree(state)
	state.quest_resolver = Callable(QuestCatalog, "load_quest")
	return state

func test_failed_scene_remains_replayable_and_success_is_origin_scoped():
	var state = _state()
	var spec := {"dialogue": "nav_echo_nest", "once": true}
	var run: NarrativeScene = state.narrative().begin_scene("origin", Vector2i(1, 1), spec)
	assert_not_null(run)
	run.complete(false)
	assert_false(state.is_scene_triggered("origin", Vector2i(1, 1)))
	run = state.narrative().begin_scene("origin", Vector2i(1, 1), spec)
	state.current_map_id = "another"
	run.complete(true)
	run.complete(true)
	assert_eq(state.triggered_for("origin"), [Vector2i(1, 1)])
	assert_false(state.is_scene_triggered("another", Vector2i(1, 1)))
	assert_null(state.narrative().begin_scene("origin", Vector2i(1, 1), spec))

func test_missing_scene_data_never_records_completion():
	var state = _state()
	assert_null(state.narrative().begin_scene("origin", Vector2i.ZERO, {"cutscene": "missing", "once": true}))
	assert_false(state.is_scene_triggered("origin", Vector2i.ZERO))

func test_completed_quest_rewards_are_not_repeated_by_effect_rechecks():
	var state = _state()
	var def := QuestDef.parse({"id": "q", "title": "Q", "stages": [{"type": "talk"}], "rewards": {"gold": 7}})
	state.quest_resolver = func(id): return def if id == "q" else null
	state.accept_quest("q")
	state.advance_quest("q")
	state.refresh_collect()
	state.advance_quest("q")
	assert_eq(state.gold, 7)
	assert_true(state.is_quest_done("q"))
