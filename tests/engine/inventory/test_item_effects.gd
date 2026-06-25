extends GutTest

func _potion(heal_hp: int = 0, heal_sp: int = 0, revive := false) -> ItemDef:
	var d := ItemDef.new()
	d.category = ItemDef.Category.CONSUMABLE
	d.heal_hp = heal_hp; d.heal_sp = heal_sp; d.revive = revive
	return d

func _hero(hp: int, hp_max: int, sp: int, sp_max: int, condition: int = Character.Condition.OK) -> Character:
	var c := Character.new()
	c.name = "Hero"; c.hp = hp; c.hp_max = hp_max; c.sp = sp; c.sp_max = sp_max
	c.condition = condition
	return c

func test_heal_hp_clamps_to_max():
	var c := _hero(20, 30, 0, 0)
	var ev := ItemEffects.apply(_potion(15), c)
	assert_eq(c.hp, 30)          # 20+15 → 夾到 30
	assert_eq(ev.size(), 1)

func test_heal_sp_clamps_to_max():
	var c := _hero(10, 10, 4, 8)
	ItemEffects.apply(_potion(0, 6), c)
	assert_eq(c.sp, 8)

func test_revive_restores_consciousness_and_hp():
	var c := _hero(0, 22, 0, 0, Character.Condition.UNCONSCIOUS)
	var ev := ItemEffects.apply(_potion(10, 0, true), c)
	assert_true(c.is_conscious())
	assert_eq(c.hp, 10)
	assert_eq(ev.size(), 1)

func test_revive_on_dead_with_no_heal_sets_hp_one():
	var c := _hero(0, 22, 0, 0, Character.Condition.DEAD)
	ItemEffects.apply(_potion(0, 0, true), c)
	assert_true(c.is_conscious())
	assert_eq(c.hp, 1)

func test_normal_potion_on_dead_rejected():
	var c := _hero(0, 22, 0, 0, Character.Condition.DEAD)
	var ev := ItemEffects.apply(_potion(15), c)
	assert_eq(ev.size(), 0)
	assert_eq(c.hp, 0)
	assert_false(c.is_alive())

func test_revive_on_conscious_rejected():
	var c := _hero(20, 30, 0, 0, Character.Condition.OK)
	var ev := ItemEffects.apply(_potion(10, 0, true), c)
	assert_eq(ev.size(), 0)

func test_heal_on_full_rejected():
	var c := _hero(30, 30, 0, 0)
	assert_false(ItemEffects.can_use(_potion(15), c))
	assert_eq(ItemEffects.apply(_potion(15), c).size(), 0)

func test_non_consumable_rejected():
	var c := _hero(10, 30, 0, 0)
	var weapon := ItemDef.new()
	weapon.category = ItemDef.Category.WEAPON
	assert_false(ItemEffects.can_use(weapon, c))
