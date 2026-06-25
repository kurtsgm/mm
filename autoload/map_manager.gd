extends Node
# Autoload 單例 "MapManager"：持有當前地圖與衍生走位格。
# 故意不給 class_name，避免與 autoload 名稱衝突。

const MAPS_DIR := "res://content/maps"

var current_map: MapData
var current_grid: GridData

func load_text(text: String) -> MapData:
	var map := MapAsciiImporter.parse(text)
	assert(map != null, "MapManager.load_text: invalid map text")
	_set_current(map)
	return map

func load_text_file(path: String) -> MapData:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "MapManager.load_text_file: cannot read %s" % path)
	var map := load_text(text)
	map.map_id = path.get_file().get_basename()  # "level01.txt" → "level01"
	return map

func load_by_id(id: String) -> MapData:
	return load_text_file("%s/%s.txt" % [MAPS_DIR, id])

func _set_current(map: MapData) -> void:
	current_map = map
	current_grid = MapBuilder.to_grid_data(map)

# 載入地圖並重套「已清遭遇」座標（切換/讀檔重入地圖共用，避免已清的怪復活）。
func enter_map(map_id: String, cleared_positions: Array = []) -> MapData:
	var map := load_by_id(map_id)
	for pos in cleared_positions:
		map.clear_encounter(pos)
	return map
