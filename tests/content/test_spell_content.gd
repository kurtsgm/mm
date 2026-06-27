extends GutTest

func test_spark_fields():
	var s: SpellDef = load("res://content/spells/spark.tres")
	assert_eq(s.id, "spark")
	assert_eq(s.effect, SpellDef.Effect.DAMAGE)
	assert_eq(s.target, SpellDef.Target.SINGLE_ENEMY)
	assert_eq(s.element, SpellDef.Element.FIRE)
	assert_eq(s.scale_stat, SpellDef.ScaleStat.INTELLECT)
	assert_eq(s.sp_cost, 2)

func test_flame_wave_is_aoe():
	var s: SpellDef = load("res://content/spells/flame_wave.tres")
	assert_eq(s.target, SpellDef.Target.ALL_ENEMIES)
	assert_eq(s.effect, SpellDef.Effect.DAMAGE)

func test_weaken_is_armor_debuff():
	var s: SpellDef = load("res://content/spells/weaken.tres")
	assert_eq(s.effect, SpellDef.Effect.STATUS)
	assert_eq(s.target, SpellDef.Target.SINGLE_ENEMY)
	assert_eq(s.status_stat, StatusEffect.Stat.ARMOR)
	assert_eq(s.status_amount, -2)

func test_heal_scales_personality():
	var s: SpellDef = load("res://content/spells/heal.tres")
	assert_eq(s.effect, SpellDef.Effect.HEAL)
	assert_eq(s.scale_stat, SpellDef.ScaleStat.PERSONALITY)

func test_revive_is_fixed():
	var s: SpellDef = load("res://content/spells/revive.tres")
	assert_eq(s.effect, SpellDef.Effect.REVIVE)
	assert_eq(s.scale_stat, SpellDef.ScaleStat.NONE)

func test_bless_is_accuracy_buff():
	var s: SpellDef = load("res://content/spells/bless.tres")
	assert_eq(s.target, SpellDef.Target.ALL_ALLIES)
	assert_eq(s.status_stat, StatusEffect.Stat.ACCURACY)
	assert_eq(s.status_amount, 3)

func test_teleport_and_town_portal_are_field_only():
	var t: SpellDef = load("res://content/spells/teleport.tres")
	assert_eq(t.effect, SpellDef.Effect.TELEPORT)
	assert_true(t.is_field_usable())
	assert_false(t.is_combat_usable())
	var tp: SpellDef = load("res://content/spells/town_portal.tres")
	assert_eq(tp.effect, SpellDef.Effect.RECALL)

func test_goblin_fire_weakness():
	var d: MonsterDef = load("res://content/monsters/goblin.tres")
	assert_eq(d.resistances.get(SpellDef.Element.FIRE, 0), -50)

func test_ogre_resistances():
	var d: MonsterDef = load("res://content/monsters/ogre.tres")
	assert_eq(d.resistances.get(SpellDef.Element.FIRE, 0), 50)
	assert_eq(d.resistances.get(SpellDef.Element.COLD, 0), -25)
