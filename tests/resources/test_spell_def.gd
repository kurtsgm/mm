extends GutTest

func test_defaults():
	var s := SpellDef.new()
	assert_eq(s.id, "")
	assert_eq(s.effect, SpellDef.Effect.DAMAGE)
	assert_eq(s.target, SpellDef.Target.SINGLE_ENEMY)
	assert_eq(s.scale_stat, SpellDef.ScaleStat.NONE)
	assert_eq(s.element, SpellDef.Element.MAGIC)
	assert_eq(s.sp_cost, 0)

func test_holds_fields():
	var s := SpellDef.new()
	s.id = "spark"; s.display_name = "火花"
	s.school = SpellDef.School.ARCANE
	s.effect = SpellDef.Effect.DAMAGE
	s.power = 4; s.scale_stat = SpellDef.ScaleStat.INTELLECT
	s.scale_per_point = 0.5; s.element = SpellDef.Element.FIRE; s.sp_cost = 2
	assert_eq(s.id, "spark")
	assert_eq(s.power, 4)
	assert_eq(s.scale_per_point, 0.5)

func test_damage_is_combat_only():
	var s := SpellDef.new(); s.effect = SpellDef.Effect.DAMAGE
	assert_true(s.is_combat_usable())
	assert_false(s.is_field_usable())

func test_heal_is_dual_context():
	var s := SpellDef.new(); s.effect = SpellDef.Effect.HEAL
	assert_true(s.is_combat_usable())
	assert_true(s.is_field_usable())

func test_buff_is_combat_only():
	var s := SpellDef.new(); s.effect = SpellDef.Effect.STATUS
	assert_true(s.is_combat_usable())
	assert_false(s.is_field_usable())

func test_teleport_is_field_only():
	var s := SpellDef.new(); s.effect = SpellDef.Effect.TELEPORT
	assert_false(s.is_combat_usable())
	assert_true(s.is_field_usable())

func test_recall_is_field_only():
	var s := SpellDef.new(); s.effect = SpellDef.Effect.RECALL
	assert_false(s.is_combat_usable())
	assert_true(s.is_field_usable())
