extends GutTest

# 建一張地圖（含 encounters + 鄰接），mirror test_world_stitch.gd 風格。
func _map(id: String, w: int, h: int, neighbors: Dictionary, encs: Dictionary, uids: Dictionary) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.neighbors = neighbors
	m.encounters = encs
	m.encounter_uids = uids
	return m

var _world: Dictionary = {}

func _loader(id: String) -> MapData:
	return _world.get(id, null)

func _none_defeated(_uid: String) -> bool:
	return false

func _no_saved(_map_id: String) -> Dictionary:
	return {}

func test_collect_includes_east_neighbor_at_global_offset():
	# a(5x5) 東接 e(5x5)；e 在 (1,2) 有一隻怪 → 全域格 = (1+5, 2) = (6,2)。
	var a := _map("a", 5, 5, {GridDirection.Dir.EAST: "e"}, {}, {})
	var e := _map("e", 5, 5, {GridDirection.Dir.WEST: "a"}, {Vector2i(1, 2): "g"}, {Vector2i(1, 2): "u-e"})
	_world = {"a": a, "e": e}
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), Callable(self, "_none_defeated"), Callable(self, "_no_saved"))
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["uid"], "u-e")
	assert_eq(rows[0]["group"], "g")
	assert_eq(rows[0]["cell"], Vector2i(6, 2), "鄰圖怪以全域 cell 偏移呈現")

func test_collect_excludes_current_map_monsters():
	# a 自己有怪；collect 不該含 a（current 由別的層畫）。
	var a := _map("a", 5, 5, {GridDirection.Dir.EAST: "e"}, {Vector2i(0, 0): "g"}, {Vector2i(0, 0): "u-a"})
	var e := _map("e", 5, 5, {GridDirection.Dir.WEST: "a"}, {Vector2i(0, 0): "g"}, {Vector2i(0, 0): "u-e"})
	_world = {"a": a, "e": e}
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), Callable(self, "_none_defeated"), Callable(self, "_no_saved"))
	var uids: Array = []
	for r in rows:
		uids.append(r["uid"])
	assert_false(uids.has("u-a"), "current map 的怪不在 neighbor 清單")
	assert_true(uids.has("u-e"))

func test_collect_excludes_defeated():
	var a := _map("a", 5, 5, {GridDirection.Dir.EAST: "e"}, {}, {})
	var e := _map("e", 5, 5, {GridDirection.Dir.WEST: "a"}, {Vector2i(1, 1): "g"}, {Vector2i(1, 1): "u-e"})
	_world = {"a": a, "e": e}
	var is_def := func(uid: String) -> bool: return uid == "u-e"
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), is_def, Callable(self, "_no_saved"))
	assert_eq(rows.size(), 0, "已擊敗的鄰圖怪不顯示")

func test_collect_applies_saved_position():
	# e 的怪存檔已移動到 (3,3) → 全域 = (3+5, 3) = (8,3)。
	var a := _map("a", 5, 5, {GridDirection.Dir.EAST: "e"}, {}, {})
	var e := _map("e", 5, 5, {GridDirection.Dir.WEST: "a"}, {Vector2i(1, 1): "g"}, {Vector2i(1, 1): "u-e"})
	_world = {"a": a, "e": e}
	var saved := func(map_id: String) -> Dictionary:
		if map_id == "e":
			return {"u-e": {"cell": Vector2i(3, 3), "state": 1}}
		return {}
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), Callable(self, "_none_defeated"), saved)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["cell"], Vector2i(8, 3), "套用存檔位置後再加全域偏移")

func test_collect_handles_non_dictionary_saved():
	# saved_provider 回非 Dictionary（如 null）時不 crash，當空處理。
	var a := _map("a", 5, 5, {GridDirection.Dir.EAST: "e"}, {}, {})
	var e := _map("e", 5, 5, {GridDirection.Dir.WEST: "a"}, {Vector2i(0, 0): "g"}, {Vector2i(0, 0): "u-e"})
	_world = {"a": a, "e": e}
	var bad := func(_map_id: String): return null
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), Callable(self, "_none_defeated"), bad)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["cell"], Vector2i(5, 0), "non-Dictionary saved → 當空、用 home 格（仍加全域偏移：e 為東鄰 ox=5）")

func test_collect_no_neighbors_returns_empty():
	var a := _map("a", 5, 5, {}, {Vector2i(0, 0): "g"}, {Vector2i(0, 0): "u-a"})
	_world = {"a": a}
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), Callable(self, "_none_defeated"), Callable(self, "_no_saved"))
	assert_eq(rows.size(), 0, "無鄰圖 → 空")
