extends GutTest

func test_unknown_model_has_false_and_null_scene():
	assert_false(DecorationCatalog.has_model("does_not_exist"))
	assert_null(DecorationCatalog.get_scene("does_not_exist"))
