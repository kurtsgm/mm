extends Node3D

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://content/maps/level01.json")
	($WorldBuilder as WorldBuilder).build(MapImporter.parse(text))
