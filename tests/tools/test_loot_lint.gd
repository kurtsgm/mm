extends GutTest

# LootLint 掉落內容一致性檢查（純函式）測試。

func _base(id: String, lo: int, hi: int, w: int) -> ItemDef:
	var d := ItemDef.new()
	d.id = id
	d.min_level = lo
	d.max_level = hi
	d.drop_weight = w
	return d

func test_reports_gap_when_band_uncovered() -> void:
	# 只有 1..10 有覆蓋，11..100 無 → 應回報缺口
	var issues := LootLint.check([_base("a", 1, 10, 5)])
	assert_true(issues.size() > 0)

func test_ok_when_full_coverage() -> void:
	var bases := [_base("a", 1, 100, 5)]
	var issues := LootLint.check(bases)
	# 覆蓋滿；unique base 檢查另計（此處 bases 不含 unique base 會回報）— 用寬鬆斷言
	for s in issues:
		assert_false(s.find("覆蓋") != -1, "不應有覆蓋缺口：%s" % s)

# 涵蓋所有神器 base_id ＋ 一般 unique base_id ＋ 滿等級帶的合法 base 集
func _bases_with_all_ids() -> Array:
	var out: Array = []
	for id in ["amulet_of_power", "iron_ring", "lucky_charm", "ring_of_kings",
		"dragonbone_sword", "dragon_scale", "steel_blade", "plate_armor", "short_sword"]:
		out.append(_base(id, 1, 100, 5))
	return out

# 紅先：缺神器 base_id 時，lint 應回報「神器 ... base_id ...」——實作前不會有此訊息
func test_lint_flags_missing_artifact_base() -> void:
	var issues := LootLint.check([_base("filler", 1, 100, 5)])
	var found := false
	for msg in issues:
		if String(msg).find("神器") != -1 and String(msg).find("base_id") != -1:
			found = true
	assert_true(found, "缺神器 base 時 lint 應回報")

# 正向守關：base 齊全時不應有任何神器問題
func test_artifacts_pass_lint() -> void:
	var issues := LootLint.check(_bases_with_all_ids())
	for msg in issues:
		assert_false(String(msg).find("神器") != -1, "不應有神器問題：%s" % msg)

func test_artifact_count_is_seven() -> void:
	assert_eq(UniqueCatalog.artifacts().size(), ArtifactSet.SET_SIZE)
