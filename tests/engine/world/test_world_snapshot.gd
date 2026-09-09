extends GutTest

func test_snapshot_is_detached_from_source_and_query_results():
	var opened := {"east": [Vector2i(1, 1)]}
	var monsters := {"east": {"u": {"cell": Vector2i(-1, 2), "state": 1}}}
	var state := WorldSnapshot.new(opened, {}, {}, monsters)
	opened["east"].clear()
	monsters["east"]["u"]["cell"] = Vector2i.ZERO
	assert_true(state.opened_for("east").has(Vector2i(1, 1)))
	assert_eq(state.monsters_for("east")["u"]["cell"], Vector2i(-1, 2))
	var queried := state.monsters_for("east")
	queried["u"]["cell"] = Vector2i(9, 9)
	state.opened_for("east").clear()
	assert_true(state.opened_for("east").has(Vector2i(1, 1)))
	assert_eq(state.monsters_for("east")["u"]["cell"], Vector2i(-1, 2))

func test_progress_is_scoped_by_origin_map_and_uid():
	var state := WorldSnapshot.new({}, {"east": [Vector2i(1, 1)]}, {"defeated": true})
	assert_true(state.encounter_defeated("east", Vector2i(1, 1), "u"))
	assert_false(state.encounter_defeated("west", Vector2i(1, 1), "u"))
	assert_true(state.encounter_defeated("west", Vector2i(9, 9), "defeated"))
	assert_eq(state.opened_for("missing"), {})
	assert_eq(state.monsters_for("missing"), {})
