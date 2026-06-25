class_name GridMovement
extends Object

enum Move { FORWARD, BACKWARD, STRAFE_LEFT, STRAFE_RIGHT }

static func direction_of(facing: int, move: int) -> int:
	match move:
		Move.FORWARD:
			return facing
		Move.BACKWARD:
			return GridDirection.opposite(facing)
		Move.STRAFE_LEFT:
			return GridDirection.turn_left(facing)
		Move.STRAFE_RIGHT:
			return GridDirection.turn_right(facing)
		_:
			return facing

static func resolve(grid: GridData, pos: Vector2i, facing: int, move: int) -> Vector2i:
	var target := pos + GridDirection.to_vector(direction_of(facing, move))
	if grid.is_walkable(target):
		return target
	return pos
