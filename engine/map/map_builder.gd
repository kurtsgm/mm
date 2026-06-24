class_name MapBuilder
extends Object

static func is_walkable_type(tile_type: int) -> bool:
	return tile_type != MapData.TileType.WALL

static func to_grid_data(map: MapData) -> GridData:
	var grid := GridData.new(map.width, map.height)
	for y in map.height:
		for x in map.width:
			var pos := Vector2i(x, y)
			if not is_walkable_type(map.get_tile(pos)):
				grid.set_solid(pos, true)
	return grid
