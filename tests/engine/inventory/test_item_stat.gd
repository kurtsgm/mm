extends GutTest

func test_name_roundtrip():
	assert_eq(ItemStat.to_name(ItemStat.S.MIGHT), "might")
	assert_eq(ItemStat.from_name("might"), ItemStat.S.MIGHT)
	assert_eq(ItemStat.from_name("hp_max"), ItemStat.S.HP_MAX)

func test_from_name_unknown_returns_minus_one():
	assert_eq(ItemStat.from_name("nope"), -1)

func test_item_def_new_fields_default():
	var d := ItemDef.new()
	assert_eq(d.min_level, 1)
	assert_eq(d.max_level, 999)
	assert_eq(d.drop_weight, 0)
	assert_eq(d.slot_tag, "")
