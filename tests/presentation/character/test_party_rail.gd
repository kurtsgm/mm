extends GutTest

func _members(n: int) -> Array:
	var out: Array = []
	for i in n:
		var c := Character.new()
		c.name = "C%d" % i
		c.char_class = "Knight"
		c.level = 1 + i
		c.hp = 10 + i
		c.hp_max = 30
		out.append(c)
	return out

func _rail(n: int, sel: int) -> PartyRail:
	var rail := PartyRail.new()
	add_child_autofree(rail)
	rail.refresh(_members(n), sel)
	return rail

func test_one_row_per_member():
	var rail := _rail(3, 0)
	assert_eq(rail.row_count(), 3)

func test_selected_index_tracked():
	var rail := _rail(4, 2)
	assert_eq(rail.selected(), 2)

func test_refresh_rebuilds_on_new_party():
	var rail := _rail(2, 0)
	rail.refresh(_members(5), 1)
	assert_eq(rail.row_count(), 5)
	assert_eq(rail.selected(), 1)
