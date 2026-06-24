class_name MapData
extends Resource

enum TileType { FLOOR = 0, WALL = 1, DOOR = 2, STAIRS_UP = 3, STAIRS_DOWN = 4 }

@export var map_id: String
@export var width: int
@export var height: int
@export var tiles: PackedInt32Array
@export var start_pos: Vector2i
@export var start_facing: int  # GridDirection.Dir；0 = NORTH

func get_tile(pos: Vector2i) -> int:
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return TileType.WALL
	return tiles[pos.y * width + pos.x]
