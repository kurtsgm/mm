class_name WorldBuilder
extends Node3D

const WALL_HEIGHT := 3.0

var _floor_grid: GridMap
var _feature_grid: GridMap

# theme 為 null 時由 ThemeCatalog 依 map.theme_id 解析（測試可注入主題）。
func build(map: MapData, theme: DungeonTheme = null) -> void:
	if theme == null:
		theme = ThemeCatalog.get_theme(map.theme_id)
	_ensure_grids()
	_floor_grid.clear()
	_feature_grid.clear()
	for grid in [_floor_grid, _feature_grid]:
		grid.mesh_library = theme.mesh_library
		grid.cell_size = Vector3(GridGeometry.CELL_SIZE, WALL_HEIGHT, GridGeometry.CELL_SIZE)
		# 原點對齊 GridGeometry.cell_to_world（cell x/z → x*CELL，無半格偏移）。
		# 預設 cell_center_x/z=true 會 +半格 → 玩家偏移、穿牆。y 也用 corner-based。
		grid.cell_center_x = false
		grid.cell_center_y = false
		grid.cell_center_z = false
	var lib := theme.mesh_library
	var floor_id := lib.find_item_by_name(theme.floor_item)
	var ceiling_id := -1
	if theme.has_ceiling:
		ceiling_id = lib.find_item_by_name(theme.ceiling_item)
	for y in map.height:
		for x in map.width:
			var t := map.get_tile(Vector2i(x, y))
			if t != MapData.TileType.WALL:
				if floor_id != -1:
					_floor_grid.set_cell_item(Vector3i(x, 0, y), floor_id)
				if ceiling_id != -1:
					_feature_grid.set_cell_item(Vector3i(x, 1, y), ceiling_id)
			if theme.item_for_tile.has(t):
				var fid := lib.find_item_by_name(theme.item_for_tile[t])
				if fid != -1:
					_feature_grid.set_cell_item(Vector3i(x, 0, y), fid)

func _ensure_grids() -> void:
	if _floor_grid == null or not is_instance_valid(_floor_grid):
		_floor_grid = GridMap.new()
		_floor_grid.name = "FloorGrid"
		add_child(_floor_grid)
	if _feature_grid == null or not is_instance_valid(_feature_grid):
		_feature_grid = GridMap.new()
		_feature_grid.name = "FeatureGrid"
		add_child(_feature_grid)
