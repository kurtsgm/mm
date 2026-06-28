extends GutTest

func _floor_map(w: int, h: int) -> MapData:
	var map := MapData.new()
	map.width = w
	map.height = h
	var t := PackedInt32Array()
	t.resize(w * h)  # 全 0 = FLOOR
	map.tiles = t
	return map

func test_resolve_link_hit_and_miss():
	var map := _floor_map(3, 3)
	map.links = { Vector2i(2, 1): {"map": "town", "entry": "gate"} }
	assert_eq(MapTransitions.resolve_link(map, Vector2i(2, 1)), {"map": "town", "entry": "gate"})
	assert_eq(MapTransitions.resolve_link(map, Vector2i(0, 0)), {})
