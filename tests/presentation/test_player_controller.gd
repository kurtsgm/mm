extends GutTest

func test_nearest_equivalent_angle_shortest_path():
	var pc := PlayerController.new()
	add_child_autofree(pc)
	# turning toward WEST yaw (-3PI/2) from 0 should pick the equivalent +PI/2 (no big spin)
	assert_almost_eq(pc._nearest_equivalent_angle(0.0, -3.0 * PI / 2.0), PI / 2.0, 0.0001)
	# toward EAST yaw (-PI/2) from 0 is already the nearest
	assert_almost_eq(pc._nearest_equivalent_angle(0.0, -PI / 2.0), -PI / 2.0, 0.0001)

func test_nearest_equivalent_angle_invariants():
	var pc := PlayerController.new()
	add_child_autofree(pc)
	var current := 1.3
	for target in [0.0, -PI / 2.0, -PI, -3.0 * PI / 2.0, PI, TAU]:
		var r: float = pc._nearest_equivalent_angle(current, target)
		# never rotates more than half a turn
		assert_lt(absf(r - current), PI + 0.0001, "delta within half turn for target %s" % target)
		# result stays congruent to target modulo TAU
		var diff: float = fposmod(r - target, TAU)
		assert_true(diff < 0.0001 or diff > TAU - 0.0001, "r congruent to target mod TAU for %s" % target)

func test_input_actions_registered():
	for action in ["move_forward", "move_back", "strafe_left", "strafe_right", "turn_left", "turn_right"]:
		assert_true(InputMap.has_action(action), "missing input action: %s" % action)
		assert_gt(InputMap.action_get_events(action).size(), 0, "no key bound to %s" % action)

func _make_pc(grid: GridData, pos: Vector2i, facing: int) -> PlayerController:
	var pc := PlayerController.new()
	add_child_autofree(pc)
	pc.setup(grid, pos, facing)
	return pc

func test_setup_emits_facing_changed():
	var pc := PlayerController.new()
	add_child_autofree(pc)
	watch_signals(pc)
	pc.setup(GridData.new(3, 3), Vector2i(1, 1), GridDirection.Dir.EAST)
	assert_signal_emitted_with_parameters(pc, "facing_changed", [GridDirection.Dir.EAST])

func test_move_emits_entered_cell_with_new_pos():
	var pc := _make_pc(GridData.new(3, 3), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)  # 北 → (1,0)
	assert_signal_emitted_with_parameters(pc, "entered_cell", [Vector2i(1, 0)])

func test_blocked_move_does_not_emit_entered_cell():
	var grid := GridData.new(3, 3)
	grid.set_solid(Vector2i(1, 0), true)  # 北邊是牆
	var pc := _make_pc(grid, Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)  # 撞牆，不動
	assert_signal_not_emitted(pc, "entered_cell")

func test_turn_emits_facing_changed():
	var pc := _make_pc(GridData.new(3, 3), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_turn(GridDirection.turn_right(GridDirection.Dir.NORTH))  # → EAST
	assert_signal_emitted_with_parameters(pc, "facing_changed", [GridDirection.Dir.EAST])

func test_disabled_ignores_input():
	var pc := _make_pc(GridData.new(3, 3), Vector2i(1, 1), GridDirection.Dir.NORTH)
	pc.set_enabled(false)
	var ev := InputEventAction.new()
	ev.action = "move_forward"
	ev.pressed = true
	pc._unhandled_input(ev)
	assert_eq(pc._pos, Vector2i(1, 1))  # 沒移動

func test_enabled_processes_input():
	var pc := _make_pc(GridData.new(3, 3), Vector2i(1, 1), GridDirection.Dir.NORTH)
	var ev := InputEventAction.new()
	ev.action = "move_forward"
	ev.pressed = true
	pc._unhandled_input(ev)
	assert_eq(pc._pos, Vector2i(1, 0))  # 北移動一格
