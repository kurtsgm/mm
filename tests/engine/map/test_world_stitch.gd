extends GutTest

var _world := {}

func _map(id: String, w: int, h: int, neighbors: Dictionary = {}) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.neighbors = neighbors
	return m

func _loader(id: String) -> MapData:
	return _world.get(id, null)

func _by_id(placed: Array) -> Dictionary:
	var d := {}
	for p in placed:
		d[p["map"].map_id] = p
	return d

func test_single_map_no_neighbors():
	var m := _map("a", 5, 5)
	var placed := WorldStitch.place(m, Callable(self, "_loader"), 6, Vector2i(2, 2))
	assert_eq(placed.size(), 1)
	assert_eq(placed[0]["map"], m)
	assert_eq(placed[0]["ox"], 0)
	assert_eq(placed[0]["oy"], 0)

func test_east_neighbor_offset():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var placed := WorldStitch.place(a, Callable(self, "_loader"), 6, Vector2i(2, 2))
	var by_id := _by_id(placed)
	assert_true(by_id.has("e"))
	assert_eq(by_id["e"]["ox"], 5)   # origin.width
	assert_eq(by_id["e"]["oy"], 0)

func test_west_and_north_offsets_use_neighbor_dims():
	var a := _map("a", 5, 5, { GridDirection.Dir.WEST: "w", GridDirection.Dir.NORTH: "n" })
	var w := _map("w", 4, 5)
	var n := _map("n", 5, 3)
	_world = { "a": a, "w": w, "n": n }
	var placed := WorldStitch.place(a, Callable(self, "_loader"), 6, Vector2i(2, 2))
	var by_id := _by_id(placed)
	assert_eq(by_id["w"]["ox"], -4)  # -nb.width
	assert_eq(by_id["w"]["oy"], 0)
	assert_eq(by_id["n"]["ox"], 0)
	assert_eq(by_id["n"]["oy"], -3)  # -nb.height

func test_diagonal_neighbor_placed_once():
	var nw := _map("nw", 5, 5, { GridDirection.Dir.EAST: "ne", GridDirection.Dir.SOUTH: "sw" })
	var ne := _map("ne", 5, 5, { GridDirection.Dir.WEST: "nw", GridDirection.Dir.SOUTH: "se" })
	var sw := _map("sw", 5, 5, { GridDirection.Dir.NORTH: "nw", GridDirection.Dir.EAST: "se" })
	var se := _map("se", 5, 5, { GridDirection.Dir.WEST: "sw", GridDirection.Dir.NORTH: "ne" })
	_world = { "nw": nw, "ne": ne, "sw": sw, "se": se }
	var placed := WorldStitch.place(nw, Callable(self, "_loader"), 8, Vector2i(2, 2))
	var by_id := _by_id(placed)
	assert_true(by_id.has("se"), "對角圖應被拼進來")
	assert_eq(by_id["se"]["ox"], 5)
	assert_eq(by_id["se"]["oy"], 5)
	var se_count := 0
	for p in placed:
		if p["map"].map_id == "se":
			se_count += 1
	assert_eq(se_count, 1, "對角圖只置入一次（visited 去重）")

func test_small_window_excludes_neighbors():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5)
	_world = { "a": a, "e": e }
	# 隊伍 (0,0)、半徑 1 → 視窗 x[-1..1]；east 圖在 x[5..9] 不相交
	var placed := WorldStitch.place(a, Callable(self, "_loader"), 1, Vector2i(0, 0))
	assert_eq(placed.size(), 1)
	assert_false(_by_id(placed).has("e"))

func test_missing_neighbor_skipped():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	_world = { "a": a }   # "e" 不在 → loader 回 null
	var placed := WorldStitch.place(a, Callable(self, "_loader"), 6, Vector2i(2, 2))
	assert_eq(placed.size(), 1, "鄰圖載入失敗 → 略過、不崩")
