extends GutTest

# Real world rebuild, monster and chest layers, save signal, recenter and player positioning.
# Replace only terrain/decoration construction to avoid loading the entire art library.
class WorldMain extends "res://presentation/world/main.gd":
	func _setup_environment() -> void:
		pass
	func _rebuild_world() -> void:
		_world_renderer.region_builder = _build_marker
		super._rebuild_world()
	func _build_marker(container: Node3D, _map: MapData) -> void:
		var marker := Node3D.new()
		marker.name = "StaticTerrain"
		container.add_child(marker)

var game: WorldMain

func before_each():
	GameState.party = Party.create_default()
	GameState.quests = {}
	GameState.opened_objects = {}
	GameState.cleared_encounters = {}
	GameState.defeated_encounters = {}
	GameState.monster_state = {}
	game = WorldMain.new()
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

func _chest_scene(id: String) -> String:
	return game._world_renderer._chests[id].get_child(0).scene_file_path

func test_save_restore_updates_pooled_neighbor_and_monsters_then_recenters():
	var renderer := game._world_renderer
	var neighbor_terrain = renderer._regions["wild_ne"].get_node("StaticTerrain")
	var neighbor_closed := _chest_scene("wild_ne")
	var neighbor := MapManager.peek_map("wild_ne")
	var home := Vector2i(5, 5)
	var uid := neighbor.get_encounter_uid(home)
	# Keep the monster across the west border of its origin map in the saved state.
	GameState.monster_state = {"wild_ne": {uid: {"cell": Vector2i(-1, 2), "state": OverworldMonsters.State.CHASING}}}
	var saved := SaveSerializer.from_dict(SaveSerializer.to_dict(SaveSystem.capture()))
	GameState.mark_object_opened("wild_ne", Vector2i(9, 5))
	GameState.mark_encounter_cleared("wild_ne", home)
	game._rebuild_world()
	assert_ne(_chest_scene("wild_ne"), neighbor_closed)
	assert_true(game._overworld_monsters.combat_info(uid).is_empty())
	assert_true(neighbor.has_encounter(home), "定義仍存在，狀態投影才排除遭遇")
	game._toggle_menu(game._save_menu)
	SaveSystem.apply(saved)
	assert_eq(_chest_scene("wild_ne"), neighbor_closed, "讀檔同步沿用的鄰區寶箱")
	assert_eq(renderer._regions["wild_ne"].get_node("StaticTerrain"), neighbor_terrain)
	assert_false(game._player._enabled, "讀檔選單仍持有輸入")
	assert_false(game._overworld_monsters.combat_info(uid).is_empty())
	assert_eq(game._overworld_monsters.to_save()["wild_ne"][uid]["cell"], Vector2i(-1, 2))
	game._save_menu.close()
	assert_true(game._player._enabled)
	game._recenter_to("wild_ne", Vector2i(0, 2), Vector2i(16, 2))
	assert_eq(_chest_scene("wild_ne"), neighbor_closed)
	assert_eq(renderer._regions["wild_ne"].get_node("StaticTerrain"), neighbor_terrain)
	assert_true(MapManager.current_map.has_encounter(home))
	assert_eq(game._overworld_monsters.to_save()["wild_ne"][uid]["cell"], Vector2i(-1, 2))
