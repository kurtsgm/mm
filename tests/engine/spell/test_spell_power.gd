extends GutTest

func _caster() -> Character:
	var c := Character.new()
	c.might = 10; c.intellect = 12; c.personality = 8
	c.endurance = 6; c.speed = 7; c.accuracy = 9; c.luck = 4; c.level = 3
	return c

func _spell(stat: int, per: float, power: int) -> SpellDef:
	var s := SpellDef.new()
	s.scale_stat = stat; s.scale_per_point = per; s.power = power
	return s

func test_none_returns_fixed_power():
	assert_eq(SpellPower.magnitude(_spell(SpellDef.ScaleStat.NONE, 0.5, 6), _caster()), 6)

func test_intellect_scaling():
	# 4 + floor(0.5 * 12) = 10
	assert_eq(SpellPower.magnitude(_spell(SpellDef.ScaleStat.INTELLECT, 0.5, 4), _caster()), 10)

func test_personality_scaling():
	# 6 + floor(0.5 * 8) = 10
	assert_eq(SpellPower.magnitude(_spell(SpellDef.ScaleStat.PERSONALITY, 0.5, 6), _caster()), 10)

func test_level_scaling():
	# 1 + floor(1.0 * 3) = 4
	assert_eq(SpellPower.magnitude(_spell(SpellDef.ScaleStat.LEVEL, 1.0, 1), _caster()), 4)

func test_floor_rounding():
	# 0 + floor(0.33 * 10) = floor(3.3) = 3
	assert_eq(SpellPower.magnitude(_spell(SpellDef.ScaleStat.MIGHT, 0.33, 0), _caster()), 3)
