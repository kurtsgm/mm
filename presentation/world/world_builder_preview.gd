extends Node3D

func _ready() -> void:
	($WorldBuilder as WorldBuilder).build(TestMap.build())
