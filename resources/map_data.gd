class_name MapData
extends Resource

enum TileType { FLOOR = 0, WALL = 1, DOOR = 2, STAIRS_UP = 3, STAIRS_DOWN = 4 }

@export var map_id: String
@export var width: int
@export var height: int
@export var tiles: PackedInt32Array
@export var start_pos: Vector2i
@export var start_facing: int  # GridDirection.Dir；0 = NORTH
@export var encounters: Dictionary = {}  # Vector2i -> String（遭遇 id）
@export var encounter_uids: Dictionary = {}  # Vector2i -> String uid
@export var theme_id: String = "default"  # 對應 ThemeCatalog 的主題 id
@export var display_name: String = ""             # 顯示名（切換訊息用），空 → 退回 map_id
@export var neighbors: Dictionary = {}            # int(GridDirection.Dir) -> String(map_id)
@export var entries: Dictionary = {}              # String(name) -> { "pos": Vector2i, "facing": int }
@export var links: Dictionary = {}                # Vector2i(cell) -> { "map": String, "entry": String }
@export var decorations: Array = []         # [{ pos:Vector2i, model:String, facing:int, scale:float }]
@export var objects: Array = []            # [{ pos:Vector2i, items:Array, gold:int, model:String }]
@export var scenes: Array = []             # [{ pos:Vector2i, dialogue:String, require, once:bool }]
@export var vendors: Array = []            # [{ pos:Vector2i, id:String }]
@export var quest_givers: Array = []       # [{ pos:Vector2i, dialogue:String }]

func get_tile(pos: Vector2i) -> int:
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return TileType.WALL
	return tiles[pos.y * width + pos.x]

func has_encounter(pos: Vector2i) -> bool:
	return encounters.has(pos)

func get_encounter(pos: Vector2i) -> String:
	return encounters.get(pos, "")

func clear_encounter(pos: Vector2i) -> void:
	encounters.erase(pos)

func get_encounter_uid(pos: Vector2i) -> String:
	return encounter_uids.get(pos, "")

func has_neighbor(dir: int) -> bool:
	return neighbors.has(dir)

func get_neighbor(dir: int) -> String:
	return neighbors.get(dir, "")

func has_entry(name: String) -> bool:
	return entries.has(name)

func get_entry(name: String) -> Dictionary:
	return entries.get(name, {})

func has_link(pos: Vector2i) -> bool:
	return links.has(pos)

func get_link(pos: Vector2i) -> Dictionary:
	return links.get(pos, {})

func has_object(pos: Vector2i) -> bool:
	for o in objects:
		if o["pos"] == pos:
			return true
	return false

func get_object(pos: Vector2i) -> Dictionary:
	for o in objects:
		if o["pos"] == pos:
			return o
	return {}

func has_scene(pos: Vector2i) -> bool:
	for s in scenes:
		if s["pos"] == pos:
			return true
	return false

func get_scene(pos: Vector2i) -> Dictionary:
	for s in scenes:
		if s["pos"] == pos:
			return s
	return {}

func has_vendor(pos: Vector2i) -> bool:
	for v in vendors:
		if v["pos"] == pos:
			return true
	return false

func get_vendor(pos: Vector2i) -> Dictionary:
	for v in vendors:
		if v["pos"] == pos:
			return v
	return {}

func has_quest_giver(pos: Vector2i) -> bool:
	for q in quest_givers:
		if q["pos"] == pos:
			return true
	return false

func get_quest_giver(pos: Vector2i) -> Dictionary:
	for q in quest_givers:
		if q["pos"] == pos:
			return q
	return {}
