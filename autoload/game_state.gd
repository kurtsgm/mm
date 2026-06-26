extends Node
# Autoload 單例 "GameState"：全域玩家狀態的家。M3 持有隊伍與訊息列。
# 故意不給 class_name，避免與 autoload 名稱衝突。序列化（存讀檔）屬 M5。

var party: Party
var message_log: MessageLog
var gold: int = 0
var inventory: Inventory

var current_map_id: String = ""
var player_pos: Vector2i = Vector2i.ZERO
var player_facing: int = GridDirection.Dir.NORTH
var cleared_encounters: Dictionary = {}  # String map_id -> Array[Vector2i]
var explored: Dictionary = {}  # String map_id -> Dictionary[Vector2i -> true]（內層當 set）
var opened_objects: Dictionary = {}  # String map_id -> Array[Vector2i]
var flags: Dictionary = {}  # String flag_name -> true（全域故事旗標，當 set）
var triggered_scenes: Dictionary = {}  # String map_id -> Array[Vector2i]（once 場景已觸發）

func _ready() -> void:
	if party == null:
		party = Party.create_default()
		_seed_starting_spells()
	if message_log == null:
		message_log = MessageLog.new()
	if inventory == null:
		inventory = Inventory.new()
		_seed_starting_items()

func mark_encounter_cleared(map_id: String, pos: Vector2i) -> void:
	var list: Array = cleared_encounters.get(map_id, [])
	if not list.has(pos):
		list.append(pos)
	cleared_encounters[map_id] = list

func cleared_for(map_id: String) -> Array:
	return cleared_encounters.get(map_id, [])

func mark_object_opened(map_id: String, pos: Vector2i) -> void:
	var list: Array = opened_objects.get(map_id, [])
	if not list.has(pos):
		list.append(pos)
	opened_objects[map_id] = list

func is_object_opened(map_id: String, pos: Vector2i) -> bool:
	return opened_objects.get(map_id, []).has(pos)

func opened_for(map_id: String) -> Array:
	return opened_objects.get(map_id, [])

func set_flag(name: String) -> void:
	flags[name] = true

func clear_flag(name: String) -> void:
	flags.erase(name)

func has_flag(name: String) -> bool:
	return flags.has(name)

func mark_scene_triggered(map_id: String, pos: Vector2i) -> void:
	var list: Array = triggered_scenes.get(map_id, [])
	if not list.has(pos):
		list.append(pos)
	triggered_scenes[map_id] = list

func is_scene_triggered(map_id: String, pos: Vector2i) -> bool:
	return triggered_scenes.get(map_id, []).has(pos)

func triggered_for(map_id: String) -> Array:
	return triggered_scenes.get(map_id, [])

func mark_explored(map_id: String, pos: Vector2i, w: int, h: int) -> void:
	var seen: Dictionary = explored.get(map_id, {})
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := Vector2i(pos.x + dx, pos.y + dy)
			if c.x < 0 or c.x >= w or c.y < 0 or c.y >= h:
				continue
			seen[c] = true
	explored[map_id] = seen

func is_explored(map_id: String, pos: Vector2i) -> bool:
	return explored.get(map_id, {}).has(pos)

func explored_for(map_id: String) -> Dictionary:
	return explored.get(map_id, {})

func _seed_starting_items() -> void:
	# 骨架起始道具：讓背包/裝備系統開局即可操演。正式起始裝備屬內容期。
	inventory.add("short_sword", 1)
	inventory.add("leather", 1)
	inventory.add("potion", 2)

func _seed_starting_spells() -> void:
	# 骨架起始法術：讓施法系統開局即可操演。正式法術習得屬內容期。
	# Cleric（Marcus）預設昏迷，故另給清醒的 Paladin（Cordelia）heal，野外治療開箱可用。
	for m in party.members:
		match m.char_class:
			"Sorcerer": m.known_spells = ["spark", "flame_wave", "weaken"]
			"Cleric": m.known_spells = ["heal", "revive", "bless"]
			"Paladin": m.known_spells = ["heal"]
