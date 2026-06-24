extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

func test_ready_builds_default_party_and_log():
	var gs = GameStateScript.new()
	add_child_autofree(gs)  # 進 tree → 觸發 _ready
	assert_not_null(gs.party)
	assert_eq(gs.party.members.size(), 6)
	assert_not_null(gs.message_log)
	assert_eq(gs.message_log.size(), 0)
