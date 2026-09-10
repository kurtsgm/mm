extends GutTest

func _definition() -> QuestDef:
	return QuestDef.parse({"id": "investigation", "stages": [
		{"type": "flag", "flag": "evidence_seen", "desc": "調查證據"},
		{"type": "talk", "desc": "回報"}
	], "rewards": {"gold": 7}})

func _state():
	var gs = load("res://autoload/game_state.gd").new()
	add_child_autofree(gs)
	gs.quest_resolver = func(_id): return _definition()
	return gs

func test_flag_objective_rejects_missing_empty_and_non_string_flag():
	for value in [null, "", 42]:
		assert_null(QuestDef.parse({"stages": [{"type": "flag", "flag": value}]}))

func test_observing_evidence_before_acceptance_is_retroactive():
	var gs = _state()
	StoryEffects.apply([{"op": "set_flag", "flag": "evidence_seen"}], gs)
	gs.accept_quest("investigation")
	assert_eq(gs.quest_stage("investigation"), 1)
	assert_eq(gs.gold, 0, "Evidence alone does not grant report reward")

func test_effect_commit_advances_active_flag_goal_and_rewards_once():
	var gs = _state()
	gs.accept_quest("investigation")
	assert_eq(gs.quest_stage("investigation"), 0)
	gs.notify_enter("any_map", Vector2i(1, 1))
	assert_eq(gs.quest_stage("investigation"), 0, "Visiting is not completing evidence")
	StoryEffects.apply([{"op": "set_flag", "flag": "evidence_seen"}], gs)
	assert_eq(gs.quest_stage("investigation"), 1)
	gs.advance_quest("investigation")
	gs.advance_quest("investigation")
	StoryEffects.apply([{"op": "set_flag", "flag": "evidence_seen"}], gs)
	assert_eq(gs.gold, 7)
	assert_true(gs.is_quest_done("investigation"))

func test_failed_effect_batch_does_not_complete_flag_goal():
	var gs = _state()
	gs.accept_quest("investigation")
	var result := StoryEffects.apply([{"op": "set_flag", "flag": "evidence_seen"}, {"op": "gold", "value": -999}], gs)
	assert_false(result.ok)
	assert_false(gs.has_flag("evidence_seen"))
	assert_eq(gs.quest_stage("investigation"), 0)
