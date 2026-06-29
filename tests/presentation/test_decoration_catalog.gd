extends GutTest

func test_unknown_model_has_false_and_null_scene():
	assert_false(DecorationCatalog.has_model("does_not_exist"))
	assert_null(DecorationCatalog.get_scene("does_not_exist"))

func test_registered_town_model_loads():
	assert_true(DecorationCatalog.has_model("town_oak_ext"))
	assert_not_null(DecorationCatalog.get_scene("town_oak_ext"))

# 約定式 fallback：未登記在 _MODELS、但存在 res://content/models/<id>/<id>.tscn 也能解析。
# oak_well 是城鎮水井，沒登記到對照表，靠約定式被引用。
func test_convention_model_resolves_without_registry():
	assert_true(DecorationCatalog.has_model("oak_well"))
	assert_not_null(DecorationCatalog.get_scene("oak_well"))
