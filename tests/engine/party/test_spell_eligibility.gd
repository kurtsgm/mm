extends GutTest

func _char(cls: String, known := []) -> Character:
	var c := Character.new()
	c.name = "T"
	c.char_class = cls
	c.known_spells.assign(known)
	return c

func _spell(id: String, school: int) -> SpellDef:
	var s := SpellDef.new()
	s.id = id
	s.school = school
	return s

func test_sorcerer_can_learn_arcane():
	var res := SpellEligibility.can_learn(_char("Sorcerer"), _spell("spark", SpellDef.School.ARCANE))
	assert_true(res["ok"])
	assert_eq(res["reason"], "ok")

func test_cleric_can_learn_divine():
	var res := SpellEligibility.can_learn(_char("Cleric"), _spell("heal", SpellDef.School.DIVINE))
	assert_true(res["ok"])

func test_knight_cannot_learn_arcane():
	var res := SpellEligibility.can_learn(_char("Knight"), _spell("spark", SpellDef.School.ARCANE))
	assert_false(res["ok"])
	assert_eq(res["reason"], "wrong_school")

func test_sorcerer_cannot_learn_divine():
	var res := SpellEligibility.can_learn(_char("Sorcerer"), _spell("heal", SpellDef.School.DIVINE))
	assert_eq(res["reason"], "wrong_school")

func test_already_known_blocks():
	var res := SpellEligibility.can_learn(_char("Sorcerer", ["spark"]), _spell("spark", SpellDef.School.ARCANE))
	assert_false(res["ok"])
	assert_eq(res["reason"], "already_known")

func test_paladin_learns_divine():
	assert_true(SpellEligibility.can_learn(_char("Paladin"), _spell("bless", SpellDef.School.DIVINE))["ok"])

func test_schools_for_unknown_class_empty():
	assert_eq(SpellEligibility.schools_for_class("Robber"), [])
