extends GutTest

func test_unregistered_npc_returns_null_pair():
	var t := NpcSpriteCatalog.textures_for("nobody")
	assert_null(t["idle"], "未註冊 → idle null")
	assert_null(t["idle2"], "未註冊 → idle2 null")

func test_always_has_idle_and_idle2_keys():
	var t := NpcSpriteCatalog.textures_for("nobody")
	assert_true(t.has("idle") and t.has("idle2"), "兩個 key 一律齊備")

func test_missing_path_resolves_to_null():
	var out := NpcSpriteCatalog._resolve_spec({"idle": "res://does/not/exist.png"})
	assert_null(out["idle"], "路徑指向不存在的檔 → null")

func test_margo_sample_has_real_transparency_and_calibrated_feet():
	var texture: Texture2D = NpcSpriteCatalog.textures_for("margo")["idle"]
	assert_not_null(texture, "正式 sample 不可默默退回 placeholder")
	if texture == null:
		return
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	assert_eq(image.get_size(), Vector2i(1024, 1536))
	assert_almost_eq(image.get_pixel(0, 0).a, 0.0, 0.001, "外部必須是真透明，不能是 RGB 棋盤格")
	assert_gt(image.get_pixel(512, 700).a, 0.95, "軀幹不可被去背工具挖空")
	var used := image.get_used_rect()
	var spec := NpcSpriteCatalog.presentation_for("margo")
	assert_almost_eq(float(used.end.y) / image.get_height(), float(spec["foot_ratio"]), 0.01, "鞋底與地面基準吻合")
