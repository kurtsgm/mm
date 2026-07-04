extends GutTest

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = seed; return r

func test_eligible_filters_by_category_and_ilvl():
	# "sharp"（前綴，武器，min_ilvl 1）在 ilvl 5 的武器合格
	var ids := AffixCatalog.eligible(ItemDef.Category.WEAPON, 5, AffixCatalog.PREFIX)
	assert_true(ids.has("sharp"))
	# 高階詞綴 min_ilvl 高，ilvl 5 不合格
	assert_false(AffixCatalog.eligible(ItemDef.Category.WEAPON, 5, AffixCatalog.PREFIX).has("cruel"))

func test_roll_mods_in_range():
	var mods := AffixCatalog.roll_mods("sharp", _rng(3))
	assert_true(mods.has(ItemStat.S.ATTACK))
	var v: int = mods[ItemStat.S.ATTACK]
	assert_true(v >= 2 and v <= 5)

func test_suffix_kind_and_name():
	var e := AffixCatalog.entry("of_the_bear")
	assert_eq(int(e["kind"]), AffixCatalog.SUFFIX)
	assert_eq(AffixCatalog.name_of("of_the_bear"), "·熊之力")
