extends Node3D

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://content/maps/level01.txt")
	($WorldBuilder as WorldBuilder).build(MapAsciiImporter.parse(text))
