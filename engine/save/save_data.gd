class_name SaveData
extends RefCounted

var gold: int = 0
var map_id: String = ""
var player_pos: Vector2i = Vector2i.ZERO
var player_facing: int = 0
var party: Party = null
var cleared_encounters: Dictionary = {}  # String map_id -> Array[Vector2i]
