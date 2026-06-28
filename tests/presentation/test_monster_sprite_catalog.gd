extends GutTest

const REAL := "res://content/portraits/gerard.png"   # 專案既有資源（PortraitCatalog 用）

func test_unknown_id_returns_all_nulls():
	var out := MonsterSpriteCatalog.textures_for("no_such_monster")
	assert_eq(out.size(), 4, "四態：idle/idle2/attack/hurt")
	assert_null(out["idle"])
	assert_null(out["idle2"])
	assert_null(out["attack"])
	assert_null(out["hurt"])

func test_unregistered_id_all_null():
	# 未註冊的 id（fire_imp 尚未進表）→ 四項皆 null
	var out := MonsterSpriteCatalog.textures_for("fire_imp")
	assert_null(out["idle"])
	assert_null(out["idle2"])
	assert_null(out["attack"])
	assert_null(out["hurt"])

func test_registered_monster_has_idle2_key():
	# idle2（大地圖兩幀假動畫第二幀）為已知鍵；值可為 Texture2D 或 null（圖未放入時）。
	var out := MonsterSpriteCatalog.textures_for("goblin")
	assert_true(out.has("idle2"), "idle2 為四態之一")

func test_goblin_registered_with_three_states():
	var out := MonsterSpriteCatalog.textures_for("goblin")
	assert_not_null(out["idle"], "goblin idle 貼圖已註冊且存在")
	assert_not_null(out["attack"], "goblin attack 貼圖已註冊且存在")
	assert_not_null(out["hurt"], "goblin hurt 貼圖已註冊且存在")
	assert_true(out["idle"] is Texture2D)

func test_resolve_spec_loads_existing_and_nulls_missing():
	var out := MonsterSpriteCatalog._resolve_spec({"idle": REAL})
	assert_not_null(out["idle"], "存在路徑應 load 成 Texture")
	assert_true(out["idle"] is Texture2D)
	assert_null(out["attack"], "缺 attack 鍵 → null")
	assert_null(out["hurt"], "缺 hurt 鍵 → null")

func test_resolve_spec_nonexistent_path_is_null():
	var out := MonsterSpriteCatalog._resolve_spec({"idle": "res://content/nope_does_not_exist.png"})
	assert_null(out["idle"], "不存在路徑 → null（不 crash）")
