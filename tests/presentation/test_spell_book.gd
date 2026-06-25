extends GutTest

func test_has_and_get_known():
	assert_true(SpellBook.has_spell("spark"))
	var s := SpellBook.get_spell("spark")
	assert_not_null(s)
	assert_eq(s.id, "spark")

func test_unknown_returns_null():
	assert_false(SpellBook.has_spell("nope"))
	assert_null(SpellBook.get_spell("nope"))

func test_all_ids_covers_content():
	var ids := SpellBook.all_ids()
	assert_true(ids.has("heal"))
	assert_true(ids.has("town_portal"))
	assert_eq(ids.size(), 8)
