extends GutTest

func test_unknown_style_false_and_null():
	assert_false(ChestCatalog.has_style("nope"))
	assert_null(ChestCatalog.get_scene("nope", false))

func test_registered_chest_loads_both_states():
	assert_true(ChestCatalog.has_style("chest"))
	var closed := ChestCatalog.get_scene("chest", false)
	var opened := ChestCatalog.get_scene("chest", true)
	assert_not_null(closed)
	assert_not_null(opened)

func test_states_are_distinct_scenes():
	assert_ne(ChestCatalog.get_scene("chest", false).resource_path,
		ChestCatalog.get_scene("chest", true).resource_path)
