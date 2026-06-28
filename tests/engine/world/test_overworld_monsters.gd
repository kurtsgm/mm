extends GutTest

# ---- helpers (used by later tasks too) ----
func _open(_c: Vector2i) -> bool:
	return true

func _mk(uid: String, home: Vector2i, cell: Vector2i, state: int) -> Dictionary:
	return {"uid": uid, "group": "g", "home": home, "cell": cell, "state": state}

func _om(entries: Array) -> OverworldMonsters:
	var om := OverworldMonsters.new()
	om._list = entries
	return om

# ---- cheb ----
func test_cheb_diagonal_is_max_axis():
	assert_eq(OverworldMonsters.cheb(Vector2i(0, 0), Vector2i(3, 2)), 3)

func test_cheb_is_symmetric():
	assert_eq(OverworldMonsters.cheb(Vector2i(5, 1), Vector2i(2, 4)), 3)

func test_cheb_zero_for_same_cell():
	assert_eq(OverworldMonsters.cheb(Vector2i(2, 2), Vector2i(2, 2)), 0)

func test_constants():
	assert_eq(OverworldMonsters.AGGRO_RANGE, 4)
	assert_eq(OverworldMonsters.LEASH_RANGE, 8)

# ---- next_step (BFS) ----
func _walls_passable(walls: Dictionary, w: int, h: int) -> Callable:
	return func(c: Vector2i) -> bool:
		return c.x >= 0 and c.x < w and c.y >= 0 and c.y < h and not walls.has(c)

func test_next_step_straight_line():
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(3, 0), Callable(self, "_open"), {})
	assert_eq(step, Vector2i(1, 0))

func test_next_step_from_equals_goal():
	var step := OverworldMonsters.next_step(Vector2i(2, 2), Vector2i(2, 2), Callable(self, "_open"), {})
	assert_eq(step, Vector2i(2, 2))

func test_next_step_around_wall():
	var passable := _walls_passable({Vector2i(1, 0): true}, 3, 3)
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(2, 0), passable, {})
	assert_eq(step, Vector2i(0, 1), "牆擋住直線 → 先往下繞")

func test_next_step_no_path_returns_from():
	var passable := _walls_passable({Vector2i(1, 0): true}, 3, 1)   # 單列走道，被牆封死
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(2, 0), passable, {})
	assert_eq(step, Vector2i(0, 0), "無路 → 原地不動")

func test_next_step_goal_terminal_even_if_not_passable():
	var passable := func(_c: Vector2i) -> bool: return false   # 任何格都不可踏
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(1, 0), passable, {})
	assert_eq(step, Vector2i(1, 0), "goal 一律可當終點（怪能踏上玩家格）")

func test_next_step_avoids_occupied():
	var occupied := {Vector2i(1, 0): true}
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(2, 0), Callable(self, "_open"), occupied)
	assert_ne(step, Vector2i(1, 0), "被占用的格不踏")

func test_next_step_occupied_as_array():
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(2, 0), Callable(self, "_open"), [Vector2i(1, 0)])
	assert_ne(step, Vector2i(1, 0), "occupied 可為 Array")

# ---- lifecycle ----
func _map_with_encounters() -> MapData:
	var map := MapData.new()
	map.encounters = {Vector2i(2, 2): "g", Vector2i(5, 1): "o"}
	map.encounter_uids = {Vector2i(2, 2): "u-g", Vector2i(5, 1): "u-o"}
	return map

func _none_defeated(_uid: String) -> bool:
	return false

func test_init_from_map_brings_group_home_cell_idle():
	var om := OverworldMonsters.new()
	om.init_from_map(_map_with_encounters(), Callable(self, "_none_defeated"))
	var rows := om.live()
	assert_eq(rows.size(), 2)
	# 找出 u-g 那筆
	var g: Dictionary = {}
	for r in rows:
		if r["uid"] == "u-g":
			g = r
	assert_eq(g["group"], "g")
	assert_eq(g["cell"], Vector2i(2, 2))
	assert_eq(g["state"], OverworldMonsters.State.IDLE)
	assert_eq(om.home_of("u-g"), Vector2i(2, 2))

func test_init_from_map_excludes_defeated():
	var om := OverworldMonsters.new()
	var is_def := func(uid: String) -> bool: return uid == "u-o"
	om.init_from_map(_map_with_encounters(), is_def)
	var rows := om.live()
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["uid"], "u-g")

func test_live_has_no_home_key():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(1, 1), OverworldMonsters.State.IDLE)])
	var rows := om.live()
	assert_false(rows[0].has("home"), "live() 不外洩 home（呈現層不需要）")
	assert_true(rows[0].has("cell"))

func test_home_of_unknown_returns_sentinel():
	var om := _om([])
	assert_eq(om.home_of("nope"), Vector2i(-1, -1))

func test_remove_drops_monster():
	var om := _om([
		_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE),
		_mk("b", Vector2i(1, 0), Vector2i(1, 0), OverworldMonsters.State.IDLE),
	])
	om.remove("a")
	var rows := om.live()
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["uid"], "b")

# ---- step() state machine ----
func test_step_aggro_at_range_4_starts_chasing():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE)])
	var res := om.step(Vector2i(4, 0), Callable(self, "_open"))
	var m: Dictionary = om.live()[0]
	assert_eq(m["state"], OverworldMonsters.State.CHASING, "距離 4 → 開始追")
	assert_eq(m["cell"], Vector2i(1, 0), "並朝玩家走一步")
	assert_eq(res["moved"], ["a"])

func test_step_no_aggro_at_range_5_stays_idle():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE)])
	var res := om.step(Vector2i(5, 0), Callable(self, "_open"))
	var m: Dictionary = om.live()[0]
	assert_eq(m["state"], OverworldMonsters.State.IDLE, "距離 5 不追")
	assert_eq(m["cell"], Vector2i(0, 0), "不動")
	assert_eq(res["moved"], [])

func test_step_chasing_approaches_player():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(2, 0), OverworldMonsters.State.CHASING)])
	om.step(Vector2i(6, 0), Callable(self, "_open"))
	assert_eq(om.live()[0]["cell"], Vector2i(3, 0), "CHASING 逼近一步")

func test_step_leash_beyond_8_returns_home():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(9, 0), OverworldMonsters.State.CHASING)])
	om.step(Vector2i(10, 0), Callable(self, "_open"))
	var m: Dictionary = om.live()[0]
	assert_eq(m["state"], OverworldMonsters.State.RETURNING, "離 home 9>8 → 放棄返家")
	assert_eq(m["cell"], Vector2i(8, 0), "本步改朝 home")

func test_step_returning_ignores_player():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(2, 0), OverworldMonsters.State.RETURNING)])
	om.step(Vector2i(3, 0), Callable(self, "_open"))   # 玩家就在旁邊
	var m: Dictionary = om.live()[0]
	assert_eq(m["state"], OverworldMonsters.State.RETURNING, "返家途中無視玩家")
	assert_eq(m["cell"], Vector2i(1, 0), "繼續朝 home 走")

func test_step_returning_reaches_home_becomes_idle():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(1, 0), OverworldMonsters.State.RETURNING)])
	om.step(Vector2i(9, 9), Callable(self, "_open"))
	var m: Dictionary = om.live()[0]
	assert_eq(m["cell"], Vector2i(0, 0))
	assert_eq(m["state"], OverworldMonsters.State.IDLE, "抵 home → IDLE")

func test_step_contact_player_walks_into_standing_monster():
	var om := _om([_mk("a", Vector2i(3, 3), Vector2i(3, 3), OverworldMonsters.State.IDLE)])
	var res := om.step(Vector2i(3, 3), Callable(self, "_open"))   # 玩家走進站怪
	assert_eq(res["contact"], "a")
	assert_eq(res["moved"], [], "即時接觸不移動任何怪")
	assert_eq(om.live()[0]["cell"], Vector2i(3, 3), "怪沒移動")

func test_step_contact_monster_walks_into_player():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(1, 0), OverworldMonsters.State.CHASING)])
	var res := om.step(Vector2i(2, 0), Callable(self, "_open"))
	assert_eq(res["contact"], "a", "怪走進玩家格 → 接觸")
	assert_true(res["moved"].has("a"))

func test_step_two_monsters_never_overlap():
	# 兩怪同時想往玩家走；占用更新確保不疊格。
	var om := _om([
		_mk("a", Vector2i(0, 1), Vector2i(0, 1), OverworldMonsters.State.CHASING),
		_mk("b", Vector2i(2, 1), Vector2i(2, 1), OverworldMonsters.State.CHASING),
	])
	var passable := _walls_passable({}, 3, 3)
	om.step(Vector2i(1, 0), passable)
	var rows := om.live()
	assert_ne(rows[0]["cell"], rows[1]["cell"], "兩怪不重疊")

# ---- to_save / apply_saved ----
func test_to_save_format():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(3, 4), OverworldMonsters.State.CHASING)])
	var saved := om.to_save()
	assert_true(saved.has("a"))
	assert_eq(saved["a"]["cell"], Vector2i(3, 4))
	assert_eq(saved["a"]["state"], OverworldMonsters.State.CHASING)

func test_apply_saved_overwrites_cell_and_state_keeps_home():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE)])
	om.apply_saved({"a": {"cell": Vector2i(5, 6), "state": OverworldMonsters.State.RETURNING}})
	var m: Dictionary = om.live()[0]
	assert_eq(m["cell"], Vector2i(5, 6))
	assert_eq(m["state"], OverworldMonsters.State.RETURNING)
	assert_eq(om.home_of("a"), Vector2i(0, 0), "home 不被覆寫")

func test_apply_saved_leaves_unlisted_at_defaults():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE)])
	om.apply_saved({"other": {"cell": Vector2i(9, 9), "state": 1}})
	var m: Dictionary = om.live()[0]
	assert_eq(m["cell"], Vector2i(0, 0), "未在 saved 的怪維持預設")
	assert_eq(m["state"], OverworldMonsters.State.IDLE)

func test_save_roundtrip():
	var om := _om([
		_mk("a", Vector2i(0, 0), Vector2i(3, 1), OverworldMonsters.State.CHASING),
		_mk("b", Vector2i(4, 4), Vector2i(4, 4), OverworldMonsters.State.IDLE),
	])
	var saved := om.to_save()
	var om2 := _om([
		_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE),
		_mk("b", Vector2i(4, 4), Vector2i(4, 4), OverworldMonsters.State.IDLE),
	])
	om2.apply_saved(saved)
	var a: Dictionary = om2.live()[0]
	assert_eq(a["cell"], Vector2i(3, 1))
	assert_eq(a["state"], OverworldMonsters.State.CHASING)
