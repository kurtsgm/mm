extends GutTest

func test_defaults():
	var d := ItemDef.new()
	assert_eq(d.id, "")
	assert_eq(d.category, ItemDef.Category.WEAPON)
	assert_eq(d.attack, 0)
	assert_eq(d.armor, 0)
	assert_false(d.revive)
	assert_false(d.stackable)

func test_is_equippable_and_consumable():
	var w := ItemDef.new()
	w.category = ItemDef.Category.WEAPON
	assert_true(w.is_equippable())
	assert_false(w.is_consumable())
	var p := ItemDef.new()
	p.category = ItemDef.Category.CONSUMABLE
	assert_false(p.is_equippable())
	assert_true(p.is_consumable())

func test_holds_fields():
	var d := ItemDef.new()
	d.id = "potion"; d.display_name = "藥水"
	d.category = ItemDef.Category.CONSUMABLE
	d.heal_hp = 15; d.stackable = true; d.value = 10
	assert_eq(d.id, "potion")
	assert_eq(d.display_name, "藥水")
	assert_eq(d.heal_hp, 15)
	assert_true(d.stackable)
	assert_eq(d.value, 10)
