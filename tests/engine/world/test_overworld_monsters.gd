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
