extends Node3D

const MAP_PATH := "res://content/maps/level01.txt"

@onready var _world_builder: WorldBuilder = $WorldBuilder
@onready var _player: PlayerController = $PlayerController
@onready var _camera: Camera3D = $PlayerController/Camera3D

var _hud: Hud
var _combat_layer: CombatLayer
var _combat: CombatSystem
var _combat_pos: Vector2i

func _ready() -> void:
	var map := MapManager.load_text_file(MAP_PATH)
	_world_builder.build(map)

	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(GameState, _player)            # 先連上 facing_changed
	_player.entered_cell.connect(_on_entered_cell)

	_combat_layer = CombatLayer.new()
	add_child(_combat_layer)
	_combat_layer.combat_finished.connect(_on_combat_finished)

	_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)

func _on_entered_cell(pos: Vector2i) -> void:
	if MapManager.current_map.has_encounter(pos):
		_start_combat(pos)
		return
	var text := TileMessages.for_tile(MapManager.current_map.get_tile(pos))
	if text != "":
		GameState.message_log.push(text)

func _start_combat(pos: Vector2i) -> void:
	var id := MapManager.current_map.get_encounter(pos)
	var defs := Bestiary.group_defs_for(id)
	if defs.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var group := EncounterSystem.build_group(defs)
	_combat = CombatSystem.new(GameState.party, group, rng)
	_combat_pos = pos
	_player.set_enabled(false)
	GameState.message_log.push("遭遇怪物！")
	_combat_layer.begin(_combat, _camera)

func _on_combat_finished(result: int) -> void:
	if result == CombatSystem.Result.VICTORY:
		_grant_rewards()
		MapManager.current_map.clear_encounter(_combat_pos)
		GameState.message_log.push("戰鬥勝利！")
		_player.set_enabled(true)
	elif result == CombatSystem.Result.FLED:
		GameState.message_log.push("你們逃離了戰鬥。")
		_player.set_enabled(true)
	else:  # DEFEAT
		GameState.message_log.push("全隊覆滅……")
		_show_game_over()
	_hud.refresh()
	_combat = null

func _grant_rewards() -> void:
	var total_xp := 0
	var total_gold := 0
	for m in _combat.monsters:
		total_xp += m.xp_reward
		total_gold += m.gold_reward
	var conscious: Array = []
	for c in GameState.party.members:
		if c.is_conscious():
			conscious.append(c)
	var share := total_xp
	if conscious.size() > 0:
		share = int(total_xp / float(conscious.size()))
	var leveled := false
	for c in conscious:
		if Leveling.grant_xp(c, share) > 0:
			leveled = true
	GameState.gold += total_gold
	if leveled:
		GameState.message_log.push("有隊員升級了！")

func _show_game_over() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "GAME OVER"
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 64)
	layer.add_child(label)
	add_child(layer)
