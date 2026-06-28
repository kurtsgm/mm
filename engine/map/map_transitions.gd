class_name MapTransitions
extends Object

static func resolve_link(map: MapData, pos: Vector2i) -> Dictionary:
	if map.has_link(pos):
		return map.get_link(pos)
	return {}
