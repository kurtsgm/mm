extends GutTest

func test_starts_empty():
	var inv := Inventory.new()
	assert_true(inv.is_empty())
	assert_eq(inv.count_of("potion"), 0)
	assert_false(inv.has("potion"))

func test_add_creates_and_merges_stack():
	var inv := Inventory.new()
	inv.add("potion", 2)
	inv.add("potion", 3)
	assert_eq(inv.count_of("potion"), 5)
	assert_eq(inv.stacks().size(), 1)

func test_add_distinct_ids_separate_stacks():
	var inv := Inventory.new()
	inv.add("potion", 1)
	inv.add("sword", 1)
	assert_eq(inv.stacks().size(), 2)
	assert_true(inv.has("potion"))
	assert_true(inv.has("sword"))

func test_remove_decrements_and_drops_empty_stack():
	var inv := Inventory.new()
	inv.add("potion", 2)
	assert_eq(inv.remove("potion", 1), 1)
	assert_eq(inv.count_of("potion"), 1)
	assert_eq(inv.remove("potion", 5), 1)   # 只移除實際存量
	assert_false(inv.has("potion"))
	assert_true(inv.is_empty())

func test_remove_missing_returns_zero():
	var inv := Inventory.new()
	assert_eq(inv.remove("nope", 1), 0)

func test_add_ignores_empty_id_and_nonpositive():
	var inv := Inventory.new()
	inv.add("", 1)
	inv.add("potion", 0)
	inv.add("potion", -3)
	assert_true(inv.is_empty())

func test_stacks_returns_copies():
	var inv := Inventory.new()
	inv.add("potion", 2)
	var snap := inv.stacks()
	snap[0]["count"] = 999
	assert_eq(inv.count_of("potion"), 2)   # 內部不受外洩參考影響

func test_load_stacks_rebuilds():
	var inv := Inventory.new()
	inv.load_stacks([{"id": "potion", "count": 2}, {"id": "sword", "count": 1}])
	assert_eq(inv.count_of("potion"), 2)
	assert_eq(inv.count_of("sword"), 1)
