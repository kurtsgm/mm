class_name GridData
extends RefCounted

var width: int
var height: int
var _solid: Dictionary = {}  # Vector2i -> bool（只記實心格）

func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func set_solid(pos: Vector2i, solid: bool) -> void:
	if solid:
		_solid[pos] = true
	else:
		_solid.erase(pos)

func is_solid(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return true
	return _solid.has(pos)

func is_walkable(pos: Vector2i) -> bool:
	return in_bounds(pos) and not _solid.has(pos)
