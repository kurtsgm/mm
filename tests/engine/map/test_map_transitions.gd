extends GutTest

func _floor_map(w: int, h: int) -> MapData:
	var map := MapData.new()
	map.width = w
	map.height = h
	var t := PackedInt32Array()
	t.resize(w * h)  # 全 0 = FLOOR
	map.tiles = t
	return map

func test_edge_exit_inside_bounds_returns_empty():
	var map := _floor_map(3, 3)
	map.neighbors = { GridDirection.Dir.EAST: "east" }
	assert_eq(MapTransitions.edge_exit(map, Vector2i(1, 1), GridDirection.Dir.EAST), {})

func test_edge_exit_out_of_bounds_with_neighbor():
	var map := _floor_map(3, 3)
	map.neighbors = { GridDirection.Dir.EAST: "east" }
	var r := MapTransitions.edge_exit(map, Vector2i(2, 1), GridDirection.Dir.EAST)
	assert_eq(r, { "neighbor_id": "east", "edge_dir": GridDirection.Dir.EAST, "lateral": 1 })

func test_edge_exit_out_of_bounds_without_neighbor():
	var map := _floor_map(3, 3)
	assert_eq(MapTransitions.edge_exit(map, Vector2i(2, 1), GridDirection.Dir.EAST), {})

func test_edge_exit_north_lateral_is_x():
	var map := _floor_map(3, 3)
	map.neighbors = { GridDirection.Dir.NORTH: "n" }
	var r := MapTransitions.edge_exit(map, Vector2i(2, 0), GridDirection.Dir.NORTH)
	assert_eq(r, { "neighbor_id": "n", "edge_dir": GridDirection.Dir.NORTH, "lateral": 2 })

func test_arrival_cell_opposite_edge():
	var dest := _floor_map(4, 4)
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.EAST, 2), Vector2i(0, 2))
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.NORTH, 1), Vector2i(1, 3))
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.WEST, 0), Vector2i(3, 0))
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.SOUTH, 3), Vector2i(3, 0))

func test_arrival_cell_blocked_when_solid():
	var dest := _floor_map(3, 3)
	dest.tiles[1 * 3 + 0] = MapData.TileType.WALL  # (0,1) 設牆
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.EAST, 1), Vector2i(-1, -1))

func test_arrival_cell_lateral_out_of_range():
	var dest := _floor_map(3, 3)
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.EAST, 9), Vector2i(-1, -1))

func test_resolve_link_hit_and_miss():
	var map := _floor_map(3, 3)
	map.links = { Vector2i(2, 1): {"map": "town", "entry": "gate"} }
	assert_eq(MapTransitions.resolve_link(map, Vector2i(2, 1)), {"map": "town", "entry": "gate"})
	assert_eq(MapTransitions.resolve_link(map, Vector2i(0, 0)), {})
