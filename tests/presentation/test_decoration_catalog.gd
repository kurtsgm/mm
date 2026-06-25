extends GutTest

func test_unknown_model_has_false_and_null_scene():
	assert_false(DecorationCatalog.has_model("does_not_exist"))
	assert_null(DecorationCatalog.get_scene("does_not_exist"))

func test_registered_town_model_loads():
	assert_true(DecorationCatalog.has_model("town_oak_ext"))
	assert_not_null(DecorationCatalog.get_scene("town_oak_ext"))
