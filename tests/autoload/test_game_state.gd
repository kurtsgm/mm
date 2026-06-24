extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

func test_ready_builds_default_party_and_log():
	var gs = GameStateScript.new()
	add_child_autofree(gs)  # 進 tree → 觸發 _ready
	assert_not_null(gs.party)
	assert_eq(gs.party.members.size(), 6)
	assert_not_null(gs.message_log)
	assert_eq(gs.message_log.size(), 0)
	assert_eq(gs.gold, 0)

func _fresh_gs() -> Node:
	var gs = GameStateScript.new()
	add_child_autofree(gs)  # 進 tree → 觸發 _ready
	return gs

func test_location_defaults():
	var gs = _fresh_gs()
	assert_eq(gs.current_map_id, "")
	assert_eq(gs.player_pos, Vector2i.ZERO)
	assert_eq(gs.player_facing, GridDirection.Dir.NORTH)
	assert_eq(gs.cleared_encounters.size(), 0)

func test_mark_and_query_cleared_encounters():
	var gs = _fresh_gs()
	gs.mark_encounter_cleared("level01", Vector2i(4, 2))
	gs.mark_encounter_cleared("level01", Vector2i(4, 2))  # 重複 → 去重
	gs.mark_encounter_cleared("level01", Vector2i(7, 9))
	var list: Array = gs.cleared_for("level01")
	assert_eq(list.size(), 2)
	assert_true(list.has(Vector2i(4, 2)))
	assert_true(list.has(Vector2i(7, 9)))
	assert_eq(gs.cleared_for("nope").size(), 0)
