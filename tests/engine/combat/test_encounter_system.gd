extends GutTest

func _def(name: String, hp: int) -> MonsterDef:
	var d := MonsterDef.new()
	d.display_name = name
	d.hp_max = hp
	return d

func test_build_group_makes_one_monster_per_def():
	var defs: Array[MonsterDef] = [_def("A", 10), _def("B", 7)]
	var group := EncounterSystem.build_group(defs)
	assert_eq(group.size(), 2)
	assert_true(group[0] is Monster)
	assert_eq(group[0].name, "A")
	assert_eq(group[0].hp, 10)
	assert_eq(group[1].name, "B")
	assert_eq(group[1].hp, 7)

func test_build_group_empty():
	var defs: Array[MonsterDef] = []
	assert_eq(EncounterSystem.build_group(defs).size(), 0)
