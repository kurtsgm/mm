extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

func _gs() -> Node:
	var gs = GameStateScript.new()
	add_child_autofree(gs)  # 進 tree → 觸發 _ready
	return gs

func test_explored_defaults_empty():
	var gs = _gs()
	assert_eq(gs.explored.size(), 0)
	assert_eq(gs.explored_for("nope").size(), 0)
	assert_false(gs.is_explored("nope", Vector2i(0, 0)))

func test_mark_explored_reveals_3x3_block():
	var gs = _gs()
	gs.mark_explored("m", Vector2i(2, 2), 5, 5)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			assert_true(gs.is_explored("m", Vector2i(2 + dx, 2 + dy)),
				"(%d,%d) 應已探索" % [2 + dx, 2 + dy])
	assert_false(gs.is_explored("m", Vector2i(0, 2)), "3×3 之外仍未探索")
	assert_eq(gs.explored_for("m").size(), 9)

func test_mark_explored_filters_out_of_bounds():
	var gs = _gs()
	gs.mark_explored("m", Vector2i(0, 0), 5, 5)  # 角落：越界鄰格應濾掉
	assert_true(gs.is_explored("m", Vector2i(0, 0)))
	assert_true(gs.is_explored("m", Vector2i(1, 1)))
	assert_false(gs.is_explored("m", Vector2i(-1, 0)))
	assert_false(gs.is_explored("m", Vector2i(0, -1)))
	assert_eq(gs.explored_for("m").size(), 4, "界內只剩 (0,0)(1,0)(0,1)(1,1)")

func test_mark_explored_dedupes_on_revisit():
	var gs = _gs()
	gs.mark_explored("m", Vector2i(2, 2), 5, 5)
	var n1: int = gs.explored_for("m").size()
	gs.mark_explored("m", Vector2i(2, 2), 5, 5)  # 重訪同格
	assert_eq(gs.explored_for("m").size(), n1, "重訪不應膨脹")

func test_explored_is_per_map():
	var gs = _gs()
	gs.mark_explored("a", Vector2i(2, 2), 5, 5)
	assert_true(gs.is_explored("a", Vector2i(2, 2)))
	assert_false(gs.is_explored("b", Vector2i(2, 2)))
