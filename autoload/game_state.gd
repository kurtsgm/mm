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

func _ready() -> void:
	if party == null:
		party = Party.create_default()
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

func _seed_starting_items() -> void:
	# 骨架起始道具：讓背包/裝備系統開局即可操演。正式起始裝備屬內容期。
	inventory.add("short_sword", 1)
	inventory.add("leather", 1)
	inventory.add("potion", 2)
