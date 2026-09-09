extends GutTest

func test_all_exclusive_modes_block_exploration_and_menus():
	for mode in [GameFlow.Mode.ENGAGING, GameFlow.Mode.COMBAT, GameFlow.Mode.CHEST, GameFlow.Mode.DIALOGUE, GameFlow.Mode.CUTSCENE, GameFlow.Mode.VENDOR, GameFlow.Mode.TRAVEL, GameFlow.Mode.TRANSITION]:
		var flow := GameFlow.new()
		assert_true(flow.enter(mode, &"active"))
		assert_false(flow.can_explore())
		assert_false(flow.open_menu(&"save"))
		assert_false(flow.enter(GameFlow.Mode.COMBAT, &"second"))
		assert_false(flow.finish(&"unrelated"))
		assert_false(flow.can_explore())
		assert_true(flow.finish(&"active"))
		assert_true(flow.can_explore())

func test_handoff_never_emits_an_exploration_window():
	var flow := GameFlow.new()
	var observed: Array = []
	var record := func(): observed.append(flow.can_explore())
	flow.changed.connect(record)
	flow.open_menu(&"character")
	assert_true(flow.handoff(&"character", GameFlow.Mode.TRANSITION, &"transition"))
	assert_false(flow.finish(&"character"))
	assert_false(flow.enter(GameFlow.Mode.TRANSITION, &"other_transition"))
	assert_eq(observed, [false, false])
	flow.finish(&"transition")
	assert_eq(observed, [false, false, true])
	flow.changed.disconnect(record)

func test_invalid_handoffs_preserve_owner():
	var flow := GameFlow.new()
	flow.enter(GameFlow.Mode.DIALOGUE, &"dialogue")
	assert_false(flow.handoff(&"dialogue", GameFlow.Mode.COMBAT, &"combat"))
	assert_true(flow.owns(&"dialogue"))

func test_defeat_menu_cancel_and_load_have_distinct_return_modes():
	var flow := GameFlow.new()
	flow.enter(GameFlow.Mode.COMBAT, &"combat")
	assert_true(flow.handoff(&"combat", GameFlow.Mode.GAME_OVER, &"game_over"))
	assert_false(flow.finish(&"game_over"))
	assert_false(flow.open_menu(&"character"))
	assert_true(flow.open_menu(&"save"))
	assert_false(flow.can_save())
	assert_false(flow.handoff(&"save", GameFlow.Mode.TRANSITION, &"transition"))
	flow.finish(&"save")
	assert_eq(flow.mode, GameFlow.Mode.GAME_OVER)
	flow.open_menu(&"save")
	flow.world_loaded()
	assert_false(flow.can_explore(), "讀檔世界已就緒，但選單仍持有輸入")
	assert_true(flow.can_save())
	flow.finish(&"save")
	assert_true(flow.can_explore())

func test_engagement_hands_off_to_combat_without_unlocking():
	var flow := GameFlow.new()
	assert_true(flow.enter(GameFlow.Mode.ENGAGING, &"engagement"))
	assert_false(flow.handoff(&"engagement", GameFlow.Mode.CHEST, &"chest"))
	assert_true(flow.handoff(&"engagement", GameFlow.Mode.COMBAT, &"combat"))
	assert_false(flow.finish(&"engagement"))
	assert_false(flow.can_explore())
