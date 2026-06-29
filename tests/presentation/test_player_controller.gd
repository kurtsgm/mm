extends GutTest

var _world := {}

func _floor_map(id: String, w: int, h: int, neighbors := {}) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.neighbors = neighbors
	var t := PackedInt32Array()
	t.resize(w * h)
	m.tiles = t
	return m

func _with_wall(m: MapData, cell: Vector2i) -> MapData:
	var t := m.tiles
	t[cell.y * m.width + cell.x] = MapData.TileType.WALL
	m.tiles = t
	return m

func _loader(id: String) -> MapData:
	return _world.get(id, null)

func _null_loader(_id: String) -> MapData:
	return null

func _wg(map: MapData, loader := Callable()) -> WorldGrid:
	if not loader.is_valid():
		loader = Callable(self, "_null_loader")
	return WorldGrid.new(map, loader)

func _make_pc(world_grid: WorldGrid, pos: Vector2i, facing: int) -> PlayerController:
	var pc := PlayerController.new()
	add_child_autofree(pc)
	pc.setup(world_grid, pos, facing)
	return pc

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

func test_turn_emits_facing_changed():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_turn(GridDirection.turn_right(GridDirection.Dir.NORTH))  # → EAST
	assert_signal_emitted_with_parameters(pc, "facing_changed", [GridDirection.Dir.EAST])

func test_setup_emits_facing_changed():
	var pc := PlayerController.new()
	add_child_autofree(pc)
	watch_signals(pc)
	pc.setup(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.EAST)
	assert_signal_emitted_with_parameters(pc, "facing_changed", [GridDirection.Dir.EAST])

func test_move_emits_entered_cell_with_new_pos():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)   # 北 → (1,0)
	assert_signal_emitted_with_parameters(pc, "entered_cell", [Vector2i(1, 0)])

func test_blocked_by_wall_does_not_emit_entered_cell():
	var pc := _make_pc(_wg(_with_wall(_floor_map("a", 3, 3), Vector2i(1, 0))), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)   # 北邊牆，不動
	assert_signal_not_emitted(pc, "entered_cell")
	assert_eq(pc._pos, Vector2i(1, 1))

func test_outer_rim_blocks_move_no_signal():
	# 站最北排 (1,0) 向北 → 出界（無鄰）→ 統一 grid 視為牆，不動、不發訊號（無 edge_exit_attempted）。
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 0), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)
	assert_signal_not_emitted(pc, "entered_cell")
	assert_eq(pc._pos, Vector2i(1, 0), "外緣牆擋住不動")

func test_no_edge_exit_attempted_signal_exists():
	var pc := PlayerController.new()
	add_child_autofree(pc)
	assert_false(pc.has_signal("edge_exit_attempted"), "離散邊界訊號已移除")

func test_walk_across_into_east_neighbor():
	# 焦點圖 a(3x3) 東鄰 e(3x3)；玩家站 a 東緣 (2,1) 面向 EAST 前進 → 全域 (3,1) = e 的 local(0,1) 可走。
	var a := _floor_map("a", 3, 3, { GridDirection.Dir.EAST: "e" })
	var e := _floor_map("e", 3, 3, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var pc := _make_pc(_wg(a, Callable(self, "_loader")), Vector2i(2, 1), GridDirection.Dir.EAST)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)
	assert_signal_emitted_with_parameters(pc, "entered_cell", [Vector2i(3, 1)])
	assert_eq(pc._pos, Vector2i(3, 1), "連續走進鄰圖（全域 cell）")

func test_disabled_ignores_input():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	pc.set_enabled(false)
	var ev := InputEventAction.new()
	ev.action = "move_forward"
	ev.pressed = true
	pc._unhandled_input(ev)
	assert_eq(pc._pos, Vector2i(1, 1))

func test_enabled_processes_input():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	var ev := InputEventAction.new()
	ev.action = "move_forward"
	ev.pressed = true
	pc._unhandled_input(ev)
	assert_eq(pc._pos, Vector2i(1, 0))

func test_rebase_shifts_pos_and_swaps_grid():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(2, 2), GridDirection.Dir.NORTH)
	var g2 := _wg(_floor_map("b", 3, 3))
	pc.rebase(Vector2i(-3, 0), g2)
	assert_eq(pc._pos, Vector2i(-1, 2), "rebase 後 _pos 平移 delta")
	assert_eq(pc._world_grid, g2, "rebase 後切換到新 grid")

# --- 0.5s 可調常數 ---

func test_move_time_is_half_second():
	assert_almost_eq(PlayerController.MOVE_TIME, 0.5, 0.0001, "每格移動時間預設 0.5s")

func test_turn_time_faster_than_move_time():
	assert_lt(PlayerController.TURN_TIME, PlayerController.MOVE_TIME, "轉向比走一格快")

# --- 連續走（chaining）---

func test_attempt_move_returns_true_when_moved():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	assert_true(pc._attempt_move(GridMovement.Move.FORWARD), "成功移動回 true")

func test_attempt_move_returns_false_when_blocked():
	var pc := _make_pc(_wg(_with_wall(_floor_map("a", 3, 3), Vector2i(1, 0))), Vector2i(1, 1), GridDirection.Dir.NORTH)
	assert_false(pc._attempt_move(GridMovement.Move.FORWARD), "撞牆回 false")

func test_is_moving_true_after_successful_move():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	pc._attempt_move(GridMovement.Move.FORWARD)
	assert_true(pc._is_moving, "移動中 _is_moving 為 true（晃動依據）")

func test_try_continue_false_when_no_key_held():
	# headless 無實體按鍵 → 不會無限連走，停在原格
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	assert_false(pc._try_continue(), "無按鍵時不接續")
	assert_eq(pc._pos, Vector2i(1, 1), "無按鍵時不前進")

# --- head bob 純函式 ---

func test_bob_offset_zero_weight_is_zero():
	assert_almost_eq(PlayerController.bob_offset(1.3, 0.0, 0.06), 0.0, 0.0001, "weight=0 → 無偏移（回正）")

func test_bob_offset_peak_at_quarter_cycle():
	# sin(PI/2)=1 → 偏移 == amplitude * weight
	assert_almost_eq(PlayerController.bob_offset(PI / 2.0, 1.0, 0.06), 0.06, 0.0001, "相位頂點 = 振幅")

func test_bob_offset_scales_with_weight():
	assert_almost_eq(PlayerController.bob_offset(PI / 2.0, 0.5, 0.06), 0.03, 0.0001, "weight 線性縮放偏移")
