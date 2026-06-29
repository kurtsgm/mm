extends Node3D

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://content/maps/town_oak.json")
	($WorldBuilder as WorldBuilder).build(MapImporter.parse(text))
