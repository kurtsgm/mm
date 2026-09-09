extends GutTest

# Exercise real main/UI callbacks and fades; omit terrain/portrait-independent world rendering.
class FlowMain extends "res://presentation/world/main.gd":
	func _setup_environment() -> void:
		pass
	func _rebuild_world() -> void:
		_build_world_grid()
		_overworld_monsters = OverworldMonsters.new()

var game: FlowMain

func before_each():
	GameState.party = Party.create_default()
	GameState.quests = {}
	game = FlowMain.new()
	var player := PlayerController.new()
	player.name = "PlayerController"
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	player.add_child(camera)
	game.add_child(player)
	add_child(game)

func after_each():
	game.free()
	await get_tree().process_frame

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _assert_movement_blocked():
	var before := game._player._pos
	var event := InputEventAction.new()
	event.action = "move_forward"
	event.pressed = true
	game._player._unhandled_input(event)
	assert_false(game._player._enabled)
	assert_eq(game._player._pos, before)
	assert_false(game._player._try_continue(), "按住方向鍵也不能接續移動")

func test_transition_rejects_hotkeys_and_duplicate_transition():
	game._enter_via_link("town_oak", "gate")
	for code in [KEY_TAB, KEY_C, KEY_I, KEY_B, KEY_J, KEY_M]:
		game._unhandled_input(_key(code))
	for menu in game._menu_ids:
		assert_false(menu.is_open())
	game._enter_via_link("wild_ne", "gate")
	_assert_movement_blocked()
	await wait_seconds(0.6)
	assert_eq(GameState.current_map_id, "town_oak")
	assert_true(game._player._enabled)
	game._unhandled_input(_key(KEY_TAB))
	assert_true(game._save_menu.is_open())
	_assert_movement_blocked()
	game._save_menu.close()
	assert_true(game._player._enabled)

func test_recall_keeps_transition_locked_after_character_panel_closes():
	game._character_tab_key(CharacterPanel.Tab.SPELLS)
	var caster: Character = GameState.party.members[0]
	caster.known_spells = ["town_portal"]
	caster.sp = 10
	var result := game._character_panel.world_spell_action.call(caster, SpellBook.get_spell("town_portal")) as ActionResult
	assert_true(result.ok)
	assert_eq(caster.sp, 4)
	game._character_panel.close()
	assert_eq(game._flow.mode, GameFlow.Mode.TRANSITION)
	game._on_menu_closed(&"save")
	_assert_movement_blocked()
	await wait_seconds(0.6)
	assert_true(game._player._enabled)
	assert_eq(GameState.current_map_id, "town_oak")

func test_travel_selection_hands_off_before_late_cancel():
	game._flow.enter(GameFlow.Mode.TRAVEL, &"travel")
	game._travel_overlay.open([{"map": "town_oak", "entry": "gate", "name": "橡木鎮"}])
	game._travel_overlay._unhandled_input(_key(KEY_ENTER))
	assert_false(game._travel_overlay.is_open())
	game._travel_overlay.finished.emit()
	_assert_movement_blocked()
	assert_eq(game._flow.mode, GameFlow.Mode.TRANSITION)
	await wait_seconds(0.6)
	assert_true(game._player._enabled)

func test_character_tabs_and_other_menu_close_cannot_steal_control():
	game._unhandled_input(_key(KEY_C))
	_assert_movement_blocked()
	game._unhandled_input(_key(KEY_I))
	assert_eq(game._character_panel.current_tab(), CharacterPanel.Tab.ITEMS)
	game._on_menu_closed(&"save")
	game._toggle_menu(game._world_map)
	assert_false(game._world_map.is_open())
	_assert_movement_blocked()
	game._unhandled_input(_key(KEY_I))
	assert_false(game._character_panel.is_open())
	assert_true(game._player._enabled)

func test_chest_owner_ignores_unrelated_finished_callbacks():
	game._prompt_chest(Vector2i.ZERO)
	game._on_vendor_finished()
	game._on_dialogue_finished()
	game._on_travel_finished()
	game._toggle_menu(game._save_menu)
	_assert_movement_blocked()
	game._chest_prompt._unhandled_input(_key(KEY_N))
	assert_false(game._chest_prompt.is_open())
	assert_true(game._player._enabled)

func test_combat_flee_and_defeat_recovery():
	game._flow.enter(GameFlow.Mode.COMBAT, &"combat")
	game._on_combat_finished(CombatSystem.Result.FLED)
	assert_true(game._player._enabled)
	game._flow.enter(GameFlow.Mode.COMBAT, &"combat")
	game._on_combat_finished(CombatSystem.Result.DEFEAT)
	_assert_movement_blocked()
	game._character_tab_key(CharacterPanel.Tab.STATUS)
	assert_false(game._character_panel.is_open())
	game._toggle_menu(game._save_menu)
	assert_true(game._save_menu.is_open())
	assert_false(game._save_menu._can_save)
	game._save_menu.close()
	assert_eq(game._flow.mode, GameFlow.Mode.GAME_OVER)
	_assert_movement_blocked()
	game._toggle_menu(game._save_menu)
	# Actual SaveSystem.apply signal; no user save slots touched.
	var saved := SaveSystem.capture()
	SaveSystem.apply(saved)
	assert_null(game._game_over_layer)
	_assert_movement_blocked()
	game._save_menu.close()
	assert_true(game._player._enabled)

func test_combat_to_chest_handoff_does_not_release_input():
	game._flow.enter(GameFlow.Mode.COMBAT, &"combat")
	game._prompt_chest(Vector2i.ZERO, &"combat")
	game._flow.finish(&"combat")
	_assert_movement_blocked()
	assert_true(game._chest_prompt.is_open())
	game._chest_prompt._unhandled_input(_key(KEY_N))
	assert_true(game._player._enabled)

func test_scene_and_vendor_return_control_through_real_ui_signals():
	var pos := Vector2i(3, 3)
	MapManager.current_map.scenes = [{"pos": pos, "dialogue": "nav_echo_nest", "once": true}]
	assert_true(game._try_scene(pos))
	game._toggle_menu(game._save_menu)
	_assert_movement_blocked()
	for i in 4:
		game._dialogue_overlay._unhandled_input(_key(KEY_1))
	assert_false(game._dialogue_overlay.is_open())
	assert_true(GameState.is_scene_triggered(GameState.current_map_id, pos))
	assert_true(game._player._enabled)
	MapManager.current_map.vendors = [{"pos": pos, "id": "oak_general_store"}]
	assert_true(game._try_vendor(pos))
	_assert_movement_blocked()
	game._vendor_overlay._unhandled_input(_key(KEY_ESCAPE))
	assert_true(game._player._enabled)

func test_cutscene_dialogue_finish_does_not_release_outer_flow():
	game._play_scene_cutscene(Vector2i(4, 4), {"cutscene": "nav_echo_nest", "once": true})
	game._toggle_menu(game._save_menu)
	_assert_movement_blocked()
	# Skip the CG dwell, then finish its nested dialogue. The final fade still owns input.
	await wait_seconds(0.85)
	game._cutscene_player._unhandled_input(_key(KEY_SPACE))
	await wait_seconds(0.65)
	assert_true(game._cutscene_player._dialogue_overlay.is_open())
	for i in 4:
		game._cutscene_player._dialogue_overlay._unhandled_input(_key(KEY_1))
	game._on_dialogue_finished()
	assert_eq(game._flow.mode, GameFlow.Mode.CUTSCENE)
	_assert_movement_blocked()
	await wait_seconds(0.85)
	assert_false(game._cutscene_player.is_playing())
	assert_true(game._player._enabled)

func test_end_of_dialogue_consumes_the_key_before_resuming_movement():
	var data := DialogueData.parse({"id": "end", "start": "end", "nodes": {"end": {"text": "end", "choices": []}}})
	game._flow.enter(GameFlow.Mode.DIALOGUE, &"dialogue")
	game._dialogue_overlay.open(DialogueRunner.new(data, GameState))
	var before := game._player._pos
	Input.parse_input_event(_key(KEY_UP))
	await get_tree().process_frame
	assert_false(game._dialogue_overlay.is_open())
	assert_true(game._player._enabled)
	assert_eq(game._player._pos, before, "結束對話的方向鍵不應同時走一步")
	var release := _key(KEY_UP)
	release.pressed = false
	Input.parse_input_event(release)

func test_unsupported_world_spell_is_free_and_keeps_menu_open():
	game._character_tab_key(CharacterPanel.Tab.SPELLS)
	var caster: Character = GameState.party.members[0]
	caster.known_spells = ["teleport"]
	caster.sp = 20
	var result := game._cast_world_spell(caster, SpellBook.get_spell("teleport"))
	assert_false(result.ok)
	assert_eq(caster.sp, 20)
	assert_true(game._character_panel.is_open())
	assert_eq(game._flow.mode, GameFlow.Mode.MENU)

func test_missing_travel_destination_releases_closed_overlay():
	game._flow.enter(GameFlow.Mode.TRAVEL, &"travel")
	await game._on_travel_chosen({"map": "missing", "entry": "missing"})
	assert_true(game._player._enabled)
	assert_true(game._flow.can_explore())
