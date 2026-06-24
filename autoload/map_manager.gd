extends Node
# Autoload 單例 "MapManager"：持有當前地圖與衍生走位格。
# 故意不給 class_name，避免與 autoload 名稱衝突。

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
	return load_text(text)

func _set_current(map: MapData) -> void:
	current_map = map
	current_grid = MapBuilder.to_grid_data(map)
