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
