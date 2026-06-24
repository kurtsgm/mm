class_name GridDirection
extends Object

enum Dir { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }

const _VECTORS := [
	Vector2i(0, -1),  # NORTH
	Vector2i(1, 0),   # EAST
	Vector2i(0, 1),   # SOUTH
	Vector2i(-1, 0),  # WEST
]

static func turn_right(dir: int) -> int:
	return (dir + 1) % 4

static func turn_left(dir: int) -> int:
	return (dir + 3) % 4

static func opposite(dir: int) -> int:
	return (dir + 2) % 4

static func to_vector(dir: int) -> Vector2i:
	return _VECTORS[dir]
