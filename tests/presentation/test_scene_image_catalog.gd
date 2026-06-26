extends GutTest

func test_unknown_id_returns_placeholder_not_null():
	var tex := SceneImageCatalog.get_texture("nope")
	assert_not_null(tex)
	assert_true(tex is Texture2D)

func test_has_image_false_for_unregistered():
	assert_false(SceneImageCatalog.has_image("nope"))

func test_placeholder_is_deterministic_size():
	var tex := SceneImageCatalog.get_texture("demo_event")
	assert_gt(tex.get_width(), 0)
	assert_gt(tex.get_height(), 0)
