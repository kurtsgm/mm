extends GutTest

func _caster() -> Character:
	var c := Character.new(); c.name = "Cleric"; c.personality = 10
	return c

func _ally(hp: int, hp_max: int, cond: int = Character.Condition.OK) -> Character:
	var c := Character.new(); c.name = "Ally"; c.hp = hp; c.hp_max = hp_max; c.condition = cond
	return c

func _heal(power: int, scale: int = SpellDef.ScaleStat.NONE, per: float = 0.0) -> SpellDef:
	var s := SpellDef.new()
	s.effect = SpellDef.Effect.HEAL; s.power = power; s.scale_stat = scale; s.scale_per_point = per
	return s

func _revive(power: int) -> SpellDef:
	var s := SpellDef.new(); s.effect = SpellDef.Effect.REVIVE; s.power = power
	return s

func test_heal_clamps_to_max():
	var a := _ally(20, 30)
	var ev := SpellEffects.apply(_heal(15), _caster(), a)
	assert_eq(a.hp, 30)
	assert_eq(ev.size(), 1)

func test_heal_scales_with_personality():
	var a := _ally(0, 100)
	# 6 + floor(0.5 * 10) = 11
	SpellEffects.apply(_heal(6, SpellDef.ScaleStat.PERSONALITY, 0.5), _caster(), a)
	assert_eq(a.hp, 11)

func test_heal_on_full_rejected():
	var a := _ally(30, 30)
	assert_false(SpellEffects.can_cast(_heal(10), _caster(), a))
	assert_eq(SpellEffects.apply(_heal(10), _caster(), a).size(), 0)

func test_heal_on_dead_rejected():
	var a := _ally(0, 30, Character.Condition.DEAD)
	assert_eq(SpellEffects.apply(_heal(10), _caster(), a).size(), 0)

func test_revive_restores_unconscious():
	var a := _ally(0, 22, Character.Condition.UNCONSCIOUS)
	var ev := SpellEffects.apply(_revive(5), _caster(), a)
	assert_true(a.is_conscious())
	assert_eq(a.hp, 5)
	assert_eq(ev.size(), 1)

func test_revive_on_conscious_rejected():
	var a := _ally(20, 30)
	assert_eq(SpellEffects.apply(_revive(5), _caster(), a).size(), 0)
