extends GutTest

const TEST_SLOT := 0

func after_each():
	SaveSystem.delete_slot(TEST_SLOT)

func test_save_then_load_restores_global_state_and_emits_loaded():
	GameState.gold = 321
	GameState.current_map_id = "wild_ne"
	GameState.player_pos = Vector2i(2, 1)
	GameState.player_facing = GridDirection.Dir.EAST
	GameState.cleared_encounters = {}
	assert_true(SaveSystem.save_to_slot(TEST_SLOT))
	# 竄改現況，確認讀檔會覆蓋回去
	GameState.gold = 0
	GameState.player_pos = Vector2i.ZERO
	watch_signals(SaveSystem)
	assert_true(SaveSystem.load_from_slot(TEST_SLOT))
	assert_eq(GameState.gold, 321)
	assert_eq(GameState.player_pos, Vector2i(2, 1))
	assert_eq(GameState.current_map_id, "wild_ne")
	assert_signal_emitted(SaveSystem, "loaded")

func test_load_missing_slot_returns_false():
	SaveSystem.delete_slot(TEST_SLOT)
	assert_false(SaveSystem.load_from_slot(TEST_SLOT))
