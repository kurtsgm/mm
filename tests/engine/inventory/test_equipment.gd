extends GutTest

func _item(id: String, category: int, attack: int = 0, armor: int = 0) -> ItemDef:
	var d := ItemDef.new()
	d.id = id; d.category = category; d.attack = attack; d.armor = armor
	return d

func test_starts_empty():
	var e := Equipment.new()
	assert_null(e.get_item(Equipment.Slot.WEAPON))
	assert_false(e.is_equipped(Equipment.Slot.WEAPON))
	assert_eq(e.total_attack(), 0)
	assert_eq(e.total_armor(), 0)

func test_equip_weapon_sets_slot_and_attack():
	var e := Equipment.new()
	var sword := _item("sword", ItemDef.Category.WEAPON, 6, 0)
	assert_true(e.can_equip(sword))
	var displaced := e.equip(sword)
	assert_null(displaced)
	assert_eq(e.get_item(Equipment.Slot.WEAPON), sword)
	assert_eq(e.total_attack(), 6)

func test_equip_displaces_previous_in_same_slot():
	var e := Equipment.new()
	var s1 := _item("sword", ItemDef.Category.WEAPON, 6)
	var s2 := _item("axe", ItemDef.Category.WEAPON, 9)
	e.equip(s1)
	var displaced := e.equip(s2)
	assert_eq(displaced, s1)
	assert_eq(e.get_item(Equipment.Slot.WEAPON), s2)
	assert_eq(e.total_attack(), 9)

func test_total_armor_sums_across_slots():
	var e := Equipment.new()
	e.equip(_item("leather", ItemDef.Category.ARMOR, 0, 3))
	e.equip(_item("charm", ItemDef.Category.ACCESSORY, 0, 1))
	assert_eq(e.total_armor(), 4)

func test_unequip_returns_item_and_clears_slot():
	var e := Equipment.new()
	var leather := _item("leather", ItemDef.Category.ARMOR, 0, 3)
	e.equip(leather)
	var removed := e.unequip(Equipment.Slot.ARMOR)
	assert_eq(removed, leather)
	assert_false(e.is_equipped(Equipment.Slot.ARMOR))
	assert_eq(e.total_armor(), 0)

func test_cannot_equip_consumable():
	var e := Equipment.new()
	var potion := _item("potion", ItemDef.Category.CONSUMABLE)
	assert_false(e.can_equip(potion))
	assert_eq(e.slot_for(potion), -1)

func test_equipped_ids_for_serialization():
	var e := Equipment.new()
	e.equip(_item("sword", ItemDef.Category.WEAPON, 6))
	e.equip(_item("leather", ItemDef.Category.ARMOR, 0, 3))
	var ids := e.equipped_ids()
	assert_eq(ids[Equipment.Slot.WEAPON], "sword")
	assert_eq(ids[Equipment.Slot.ARMOR], "leather")
	assert_false(ids.has(Equipment.Slot.ACCESSORY))
