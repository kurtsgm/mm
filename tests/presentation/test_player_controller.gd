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
