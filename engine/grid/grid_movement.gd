class_name GridMovement
extends Object

enum Move { FORWARD, BACKWARD, STRAFE_LEFT, STRAFE_RIGHT }

static func resolve(grid: GridData, pos: Vector2i, facing: int, move: int) -> Vector2i:
	var move_dir: int
	match move:
		Move.FORWARD:
			move_dir = facing
		Move.BACKWARD:
			move_dir = GridDirection.opposite(facing)
		Move.STRAFE_LEFT:
			move_dir = GridDirection.turn_left(facing)
		Move.STRAFE_RIGHT:
			move_dir = GridDirection.turn_right(facing)
		_:
			return pos
	var target := pos + GridDirection.to_vector(move_dir)
	if grid.is_walkable(target):
		return target
	return pos
