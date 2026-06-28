extends GutTest

var _world := {}

func _floor_map(id: String, w: int, h: int, neighbors := {}) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.neighbors = neighbors
	var t := PackedInt32Array()
	t.resize(w * h)   # 全 0 = FLOOR
	m.tiles = t
	return m

func _with_wall(m: MapData, cell: Vector2i) -> MapData:
	var t := m.tiles
	t[cell.y * m.width + cell.x] = MapData.TileType.WALL
	m.tiles = t
	return m

func _loader(id: String) -> MapData:
	return _world.get(id, null)

func _null_loader(_id: String) -> MapData:
	return null

func test_single_map_resolve_and_walkable():
	var a := _floor_map("a", 3, 3)
	var wg := WorldGrid.new(a, Callable(self, "_null_loader"))
	assert_eq(wg.resolve(Vector2i(1, 1)), { "map_id": "a", "local": Vector2i(1, 1) })
	assert_true(wg.is_walkable(Vector2i(1, 1)), "焦點圖可走格")

func test_outside_region_is_wall_and_unresolved():
	var a := _floor_map("a", 3, 3)
	var wg := WorldGrid.new(a, Callable(self, "_null_loader"))
	assert_false(wg.is_walkable(Vector2i(1, -1)), "外緣無鄰 = 牆")
	assert_eq(wg.resolve(Vector2i(1, -1)), {}, "未覆蓋格 resolve 回空")

func test_wall_tile_not_walkable_but_resolvable():
	var a := _with_wall(_floor_map("a", 3, 3), Vector2i(1, 1))
	var wg := WorldGrid.new(a, Callable(self, "_null_loader"))
	assert_false(wg.is_walkable(Vector2i(1, 1)), "WALL tile 不可走")
	assert_eq(wg.resolve(Vector2i(1, 1)), { "map_id": "a", "local": Vector2i(1, 1) }, "WALL 仍可反查")

func test_east_neighbor_resolve_and_walkable():
	var a := _floor_map("a", 3, 3, { GridDirection.Dir.EAST: "e" })
	var e := _floor_map("e", 3, 3, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var wg := WorldGrid.new(a, Callable(self, "_loader"))
	# a 在原點、e 在 ox = a.width = 3
	assert_eq(wg.resolve(Vector2i(3, 1)), { "map_id": "e", "local": Vector2i(0, 1) })
	assert_true(wg.is_walkable(Vector2i(3, 1)), "鄰圖可走格")

func test_diagonal_neighbor_resolved():
	var nw := _floor_map("nw", 5, 5, { GridDirection.Dir.EAST: "ne", GridDirection.Dir.SOUTH: "sw" })
	var ne := _floor_map("ne", 5, 5, { GridDirection.Dir.WEST: "nw", GridDirection.Dir.SOUTH: "se" })
	var sw := _floor_map("sw", 5, 5, { GridDirection.Dir.NORTH: "nw", GridDirection.Dir.EAST: "se" })
	var se := _floor_map("se", 5, 5, { GridDirection.Dir.WEST: "sw", GridDirection.Dir.NORTH: "ne" })
	_world = { "nw": nw, "ne": ne, "sw": sw, "se": se }
	var wg := WorldGrid.new(nw, Callable(self, "_loader"))
	# se 對角在 (5,5)，其 local (0,0)
	assert_eq(wg.resolve(Vector2i(5, 5)), { "map_id": "se", "local": Vector2i(0, 0) })

func test_regions_match_world_stitch_place():
	var a := _floor_map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _floor_map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var wg := WorldGrid.new(a, Callable(self, "_loader"))
	var win := WorldStitch.window_for(a)
	var placed := WorldStitch.place(a, Callable(self, "_loader"), win["half"], win["center"])
	var wg_by_id := {}
	for r in wg.regions():
		wg_by_id[r["map"].map_id] = Vector2i(r["ox"], r["oy"])
	var ws_by_id := {}
	for r in placed:
		ws_by_id[r["map"].map_id] = Vector2i(r["ox"], r["oy"])
	assert_eq(wg_by_id, ws_by_id, "WorldGrid.regions 偏移與 WorldStitch.place 同源一致")
