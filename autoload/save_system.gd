extends Node
# Autoload 單例 "SaveSystem"：多槽 JSON 存讀檔。
# 故意不給 class_name，避免與 autoload 名稱衝突，比照 GameState/MapManager。

signal loaded

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 5

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
	return SaveSerializer.from_dict(raw)

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
