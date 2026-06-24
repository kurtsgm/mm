class_name GridGeometry
extends Object

const CELL_SIZE := 2.0

static func cell_to_world(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * CELL_SIZE, 0.0, pos.y * CELL_SIZE)

static func facing_to_yaw(facing: int) -> float:
	return -facing * (PI / 2.0)
