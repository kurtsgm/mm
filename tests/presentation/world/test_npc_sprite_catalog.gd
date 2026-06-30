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
