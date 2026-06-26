extends GutTest

func test_grant_adds_items_and_returns_gold():
	var inv := Inventory.new()
	var chest := {"pos": Vector2i(1, 1), "items": ["potion", "short_sword"], "gold": 50, "model": "chest"}
	var res := ChestLoot.grant(chest, inv)
	assert_eq(res["gold"], 50)
	assert_eq(res["items"], ["potion", "short_sword"])
	assert_eq(inv.count_of("potion"), 1)
	assert_eq(inv.count_of("short_sword"), 1)

func test_grant_empty_chest():
	var inv := Inventory.new()
	var chest := {"pos": Vector2i(1, 1), "items": [], "gold": 0, "model": "chest"}
	var res := ChestLoot.grant(chest, inv)
	assert_eq(res["gold"], 0)
	assert_eq(res["items"], [])
	assert_true(inv.is_empty())

func test_grant_skips_empty_id():
	var inv := Inventory.new()
	var chest := {"pos": Vector2i(1, 1), "items": ["", "potion"], "gold": 0, "model": "chest"}
	var res := ChestLoot.grant(chest, inv)
	assert_eq(res["items"], ["potion"])
	assert_eq(inv.count_of("potion"), 1)
