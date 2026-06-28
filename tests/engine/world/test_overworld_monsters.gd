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
