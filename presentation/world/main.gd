extends Node3D

const MAP_PATH := "res://content/maps/level01.txt"

@onready var _world_builder: WorldBuilder = $WorldBuilder
@onready var _player: PlayerController = $PlayerController

func _ready() -> void:
	var map := MapManager.load_text_file(MAP_PATH)
	_world_builder.build(map)
	_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)
