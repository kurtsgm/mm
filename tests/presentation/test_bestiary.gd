extends GutTest

func test_goblin_group_loads_three():
	var defs := Bestiary.group_defs_for("g")
	assert_eq(defs.size(), 3)
	assert_true(defs[0] is MonsterDef)
	assert_eq(defs[0].display_name, "哥布林")

func test_ogre_group_loads_one():
	var defs := Bestiary.group_defs_for("o")
	assert_eq(defs.size(), 1)
	assert_eq(defs[0].display_name, "食人魔")

func test_dream_wisp_group_loads_two_with_sleep_inflict():
	var defs := Bestiary.group_defs_for("dw")
	assert_eq(defs.size(), 2)
	assert_eq(defs[0].display_name, "夢魘妖")
	assert_eq(defs[0].inflict_kind, StatusEffect.Kind.SLEEP)

func test_unknown_id_returns_empty():
	assert_eq(Bestiary.group_defs_for("zzz").size(), 0)
