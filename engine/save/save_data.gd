class_name SaveData
extends RefCounted

var gold: int = 0
var map_id: String = ""
var player_pos: Vector2i = Vector2i.ZERO
var player_facing: int = 0
var party: Party = null
var inventory: Inventory = null
var cleared_encounters: Dictionary = {}  # String map_id -> Array[Vector2i]
var explored: Dictionary = {}  # String map_id -> Dictionary[Vector2i -> true]
var opened_objects: Dictionary = {}  # String map_id -> Array[Vector2i]
var flags: Dictionary = {}  # String flag -> true
var triggered_scenes: Dictionary = {}  # String map_id -> Array[Vector2i]
var quests: Dictionary = {}  # String id -> { status, stage }
var defeated_encounters: Dictionary = {}  # uid -> true
