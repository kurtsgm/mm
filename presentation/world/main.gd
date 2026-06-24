extends Node3D

@onready var _world_builder: WorldBuilder = $WorldBuilder
@onready var _player: PlayerController = $PlayerController

func _ready() -> void:
	var grid := TestMap.build()
	_world_builder.build(grid)
	_player.setup(grid, TestMap.start_pos(), TestMap.start_facing())
