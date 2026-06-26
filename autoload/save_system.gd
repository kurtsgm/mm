extends Node
# Autoload 單例 "SaveSystem"：多槽 JSON 存讀檔。
# 故意不給 class_name，避免與 autoload 名稱衝突，比照 GameState/MapManager。

signal loaded

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 5

# 由呈現層注入的道具解析器（id -> ItemDef），讀檔還原裝備用。預設空 → 裝備留空。
var item_resolver: Callable = Callable()

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]

func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func delete_slot(slot: int) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(_slot_path(slot))

func write_slot(slot: int, data: SaveData) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var raw := SaveSerializer.to_dict(data)
	raw["meta"]["saved_at"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(raw, "  "))
	f.close()
	return true

func read_slot(slot: int) -> SaveData:
	if not has_slot(slot):
		return null
	var text := FileAccess.get_file_as_string(_slot_path(slot))
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	return SaveSerializer.from_dict(raw, item_resolver)

func list_slots() -> Array:
	var out: Array = []
	for slot in SLOT_COUNT:
		out.append(_slot_meta(slot))
	return out

func _slot_meta(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var text := FileAccess.get_file_as_string(_slot_path(slot))
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY or not raw.has("meta"):
		return {}
	return raw["meta"]

func capture_from(gs) -> SaveData:
	var data := SaveData.new()
	data.gold = gs.gold
	data.map_id = gs.current_map_id
	data.player_pos = gs.player_pos
	data.player_facing = gs.player_facing
	data.party = gs.party
	data.inventory = gs.inventory
	data.cleared_encounters = gs.cleared_encounters
	data.explored = gs.explored
	data.opened_objects = gs.opened_objects
	data.flags = gs.flags
	data.triggered_scenes = gs.triggered_scenes
	data.quests = gs.quests
	data.kill_counts = gs.kill_counts
	return data

func apply_to(data: SaveData, gs, mm) -> void:
	gs.party = data.party
	gs.inventory = data.inventory
	gs.gold = data.gold
	gs.current_map_id = data.map_id
	gs.player_pos = data.player_pos
	gs.player_facing = data.player_facing
	gs.cleared_encounters = data.cleared_encounters
	gs.explored = data.explored
	gs.opened_objects = data.opened_objects
	gs.flags = data.flags
	gs.triggered_scenes = data.triggered_scenes
	gs.quests = data.quests
	gs.kill_counts = data.kill_counts
	mm.enter_map(data.map_id, gs.cleared_for(data.map_id))

func capture() -> SaveData:
	return capture_from(GameState)

func apply(data: SaveData) -> void:
	apply_to(data, GameState, MapManager)
	loaded.emit()

func save_to_slot(slot: int) -> bool:
	return write_slot(slot, capture())

func load_from_slot(slot: int) -> bool:
	var data := read_slot(slot)
	if data == null:
		return false
	apply(data)
	return true
