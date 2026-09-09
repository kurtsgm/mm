extends GutTest

# Real main/player/world/combat handoff; only terrain construction is omitted.
class EncounterMain extends "res://presentation/world/main.gd":
	func _setup_environment() -> void:
		pass
	func _rebuild_world() -> void:
		_build_world_grid()
		_overworld_monsters = OverworldMonsters.new()

var game: EncounterMain
var viewport: SubViewport

func before_each():
	GameState.party = Party.create_default()
	for character in GameState.party.members:
		character.speed = 999
	GameState.quests = {}
	GameState.opened_objects = {}
	GameState.cleared_encounters = {}
	GameState.defeated_encounters = {}
	GameState.monster_state = {}
	game = EncounterMain.new()
	var player := PlayerController.new()
	player.name = "PlayerController"
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.2
	player.add_child(camera)
	game.add_child(player)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child(viewport)
	viewport.add_child(game)
	var map := MapData.new()
	map.map_id = "encounter_test"
	map.width = 12
	map.height = 12
	map.tiles.resize(144)
	MapManager.current_map = map
	GameState.current_map_id = map.map_id
	GameState.player_pos = Vector2i(5, 5)
	game._build_world_grid()
	game._player.setup(game._world_grid, GameState.player_pos, GridDirection.Dir.NORTH)

func after_each():
	viewport.free()
	await get_tree().process_frame

func _spawn(cell: Vector2i, group := "g") -> Array:
	game._overworld_monsters._list = [
		{"uid": "engaged", "group": group, "origin_map": "encounter_test", "origin_off": Vector2i.ZERO,
		 "home": cell, "cell": cell, "state": OverworldMonsters.State.IDLE},
		{"uid": "bystander", "group": "o", "origin_map": "encounter_test", "origin_off": Vector2i.ZERO,
		 "home": Vector2i(10, 10), "cell": Vector2i(10, 10), "state": OverworldMonsters.State.IDLE},
	]
	game._monster_layer.rebuild(game._overworld_monsters.live())
	return game._monster_layer._sprites["engaged"]

func test_walking_finishes_before_same_models_enter_first_turn():
	var members := _spawn(Vector2i(5, 2))
	var nodes := members.map(func(member): return member["node"])
	assert_true(game._player._attempt_move(GridMovement.Move.FORWARD))
	assert_eq(game._flow.mode, GameFlow.Mode.ENGAGING)
	assert_false(game._player._enabled)
	assert_null(game._combat)
	game._toggle_menu(game._save_menu)
	assert_false(game._save_menu.is_open())
	await wait_seconds(0.15)
	assert_null(game._combat, "移動途中不得跑首回合")
	assert_true(game._monster_layer.visible)
	assert_true(game._player._is_busy)
	await wait_seconds(0.85)
	assert_eq(game._flow.mode, GameFlow.Mode.COMBAT)
	assert_false(game._player._is_busy)
	assert_eq(game._player._bob_weight, 0.0)
	assert_eq(game._player.position, GridGeometry.cell_to_world(Vector2i(5, 4)))
	assert_eq(game._overworld_monsters.combat_info("engaged")["cell"], Vector2i(5, 3))
	for i in nodes.size():
		var node: Node3D = nodes[i]
		assert_same(game._combat_layer._stage._sprites[game._combat.monsters[i]], node)
		assert_same(node.get_parent(), game._monster_layer)
		assert_eq(node.scale, Vector3.ONE * MonsterLayer.CLUSTER_SCALE)
		assert_eq(node.position, game._monster_layer._world_pos(Vector2i(5, 3)) + members[i]["offset"])

func test_side_contact_blocks_entry_turns_then_flee_returns_same_sprite():
	var member: Dictionary = _spawn(Vector2i(6, 5), "o")[0]
	var sprite: Sprite3D = member["node"]
	var before := sprite.global_transform
	var pixels := sprite.pixel_size
	assert_false(game._player._attempt_move(GridMovement.Move.STRAFE_RIGHT))
	assert_eq(game._flow.mode, GameFlow.Mode.ENGAGING)
	assert_eq(game._player._pos, Vector2i(5, 5))
	assert_null(game._combat)
	await wait_seconds(0.4)
	assert_eq(game._player._facing, GridDirection.Dir.EAST)
	assert_eq(GameState.player_facing, GridDirection.Dir.EAST)
	assert_eq(sprite.global_transform, before)
	assert_eq(sprite.pixel_size, pixels)
	var stage := game._combat_layer._stage
	stage.play_attack(game._combat.monsters[0])
	await wait_seconds(0.1)
	assert_lt(sprite.position.x, before.origin.x, "東側怪物往玩家方向撲，而非固定世界 Z")
	game._combat._result = CombatSystem.Result.FLED
	game._combat_layer._finish()
	assert_false(game._player._enabled, "攻擊收完才交還探索")
	game._combat_layer._on_action_selected("run") # stale click while ending
	await wait_seconds(0.5)
	assert_true(game._player._enabled)
	assert_same(game._monster_layer._sprites["engaged"][0]["node"], sprite)
	assert_eq(sprite.global_transform, before)
	assert_eq(sprite.pixel_size, pixels)
	assert_true(sprite.visible)
	assert_false(sprite.is_queued_for_deletion())
	assert_eq(game._overworld_monsters.step(Vector2i(4, 5), game._is_passable)["contact"], "")

func test_victory_removes_only_engaged_group():
	_spawn(Vector2i(5, 4))
	var bystander: Node3D = game._monster_layer._sprites["bystander"][0]["node"]
	game._player._attempt_move(GridMovement.Move.FORWARD)
	await wait_seconds(0.4)
	for monster in game._combat.monsters:
		monster.hp = 0
	game._combat._result = CombatSystem.Result.VICTORY
	game._combat_layer._finish()
	await get_tree().process_frame
	assert_true(game._player._enabled)
	assert_false(game._monster_layer._sprites.has("engaged"))
	assert_same(game._monster_layer._sprites["bystander"][0]["node"], bystander)
	assert_true(GameState.defeated_encounters.has("engaged"))
	assert_true(game._overworld_monsters.combat_info("engaged").is_empty())

func test_faster_monsters_wait_for_engagement_before_damaging_party():
	_spawn(Vector2i(5, 2))
	for character in GameState.party.members:
		character.speed = 0
	var hp := GameState.party.members.map(func(character): return character.hp)
	game._player._attempt_move(GridMovement.Move.FORWARD)
	await wait_seconds(0.15)
	assert_eq(GameState.party.members.map(func(character): return character.hp), hp)
	assert_null(game._combat)
	await wait_seconds(0.85)
	assert_eq(game._flow.mode, GameFlow.Mode.COMBAT)
	assert_not_null(game._combat_layer.combat)

func test_combat_party_cards_remain_visible_and_keep_exploration_placement():
	_spawn(Vector2i(5, 4))
	await wait_seconds(0.05)
	var exploration_rect := game._hud._party_panel.get_global_rect()
	game._player._attempt_move(GridMovement.Move.FORWARD)
	await wait_seconds(0.4)
	var strip: HBoxContainer = game._combat_layer._party_box
	var rect := strip.get_global_rect()
	assert_almost_eq(rect.position.x, exploration_rect.position.x, 0.1)
	assert_almost_eq(rect.position.y, exploration_rect.position.y, 4.0, "回合高亮的小間距不應造成隊伍列跳位")
	assert_almost_eq(rect.size.x, exploration_rect.size.x, 0.1)
	assert_almost_eq(rect.end.y, exploration_rect.end.y, 0.1)
	assert_lte(rect.end.y, viewport.get_visible_rect().end.y)
	var actions := game._combat_layer._action_bar._row.get_global_rect()
	assert_lte(actions.end.y, rect.position.y, "行動列位於隊伍列上方")
