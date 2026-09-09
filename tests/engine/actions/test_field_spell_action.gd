extends GutTest

func _caster() -> Character:
	var caster := Character.new()
	caster.hp = 10
	caster.hp_max = 20
	caster.sp = 20
	caster.known_spells = ["heal"]
	return caster

func test_valid_heal_commits_one_cost_and_effect():
	var caster := _caster()
	var spell := SpellBook.get_spell("heal")
	var result := FieldSpellAction.cast(caster, spell, [caster])
	assert_true(result.ok)
	assert_eq(caster.sp, 20 - spell.sp_cost)
	assert_gt(caster.hp, 10)

func test_invalid_target_unknown_spell_and_incapacitated_caster_are_free():
	var caster := _caster()
	caster.hp = caster.hp_max
	assert_false(FieldSpellAction.cast(caster, SpellBook.get_spell("heal"), [caster]).ok)
	caster.hp = 10
	caster.known_spells = []
	assert_false(FieldSpellAction.cast(caster, SpellBook.get_spell("heal"), [caster]).ok)
	caster.known_spells = ["heal"]
	caster.condition = Character.Condition.UNCONSCIOUS
	assert_false(FieldSpellAction.cast(caster, SpellBook.get_spell("heal"), [caster]).ok)
	assert_eq(caster.sp, 20)
	assert_eq(caster.hp, 10)

func test_group_heal_filters_invalid_targets_and_pays_once():
	var caster := _caster()
	var full := _caster()
	full.hp = full.hp_max
	var spell := SpellBook.get_spell("heal").duplicate() as SpellDef
	spell.target = SpellDef.Target.ALL_ALLIES
	assert_true(FieldSpellAction.cast(caster, spell, [full, caster, caster]).ok)
	assert_eq(caster.sp, 20 - spell.sp_cost)
	assert_eq(full.hp, full.hp_max)
