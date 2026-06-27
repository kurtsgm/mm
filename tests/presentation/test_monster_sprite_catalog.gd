extends GutTest

const REAL := "res://content/portraits/gerard.png"   # 專案既有資源（PortraitCatalog 用）

func test_unknown_id_returns_three_nulls():
	var out := MonsterSpriteCatalog.textures_for("no_such_monster")
	assert_eq(out.size(), 3)
	assert_null(out["idle"])
	assert_null(out["attack"])
	assert_null(out["hurt"])

func test_empty_table_any_id_all_null():
	# 骨架期 _SPRITES 為空表 → 任何 id 三項皆 null
	var out := MonsterSpriteCatalog.textures_for("fire_imp")
	assert_null(out["idle"])
	assert_null(out["attack"])
	assert_null(out["hurt"])

func test_resolve_spec_loads_existing_and_nulls_missing():
	var out := MonsterSpriteCatalog._resolve_spec({"idle": REAL})
	assert_not_null(out["idle"], "存在路徑應 load 成 Texture")
	assert_true(out["idle"] is Texture2D)
	assert_null(out["attack"], "缺 attack 鍵 → null")
	assert_null(out["hurt"], "缺 hurt 鍵 → null")

func test_resolve_spec_nonexistent_path_is_null():
	var out := MonsterSpriteCatalog._resolve_spec({"idle": "res://content/nope_does_not_exist.png"})
	assert_null(out["idle"], "不存在路徑 → null（不 crash）")
