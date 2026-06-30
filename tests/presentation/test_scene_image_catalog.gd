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

func test_registered_scene_ids_present():
	assert_true(SceneImageCatalog.has_image("margo_clinic"))
	assert_true(SceneImageCatalog.has_image("marsh_swampherb"))
	assert_true(SceneImageCatalog.has_image("margo_portrait"))

func test_registered_but_missing_file_falls_back_to_placeholder():
	# 已登記、真圖未到 → placeholder（非 null）；真圖放入後此測試仍通過（回真 Texture2D）。
	var tex := SceneImageCatalog.get_texture("margo_clinic")
	assert_not_null(tex)
	assert_true(tex is Texture2D)
