class_name MapBuilder
extends Object

static func is_walkable_type(tile_type: int) -> bool:
	return tile_type != MapData.TileType.WALL
