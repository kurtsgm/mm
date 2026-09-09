extends Node
# Autoload 單例 "MapManager"：持有當前地圖定義；不套用玩家進度。
# 故意不給 class_name，避免與 autoload 名稱衝突。

var current_map: MapData

func load_text(text: String) -> MapData:
	var map := MapImporter.parse(text)
	assert(map != null, "MapManager.load_text: invalid map text")
	_set_current(map)
	return map

func load_text_file(path: String) -> MapData:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "MapManager.load_text_file: cannot read %s" % path)
	var map := load_text(text)
	map.map_id = path.get_file().get_basename()  # "town_oak.json" → "town_oak"
	return map

func load_by_id(id: String) -> MapData:
	return load_text_file(ContentRegistry.path_for("maps", id))

# 無副作用載入（拼裝鄰圖用）：不動 current_map；失敗回 null（不 assert）。
func peek_map(id: String) -> MapData:
	var path := ContentRegistry.path_for("maps", id)
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return null
	var map := MapImporter.parse(text)
	if map == null:
		return null
	map.map_id = id
	return map

func _set_current(map: MapData) -> void:
	current_map = map

# 當前圖與 peek 鄰圖使用相同的完整定義；執行狀態由 WorldSnapshot 投影。
func enter_map(map_id: String) -> MapData:
	return load_by_id(map_id)
