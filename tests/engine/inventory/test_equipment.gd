extends GutTest

func before_all():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id
		if id == "sword": d.category = ItemDef.Category.WEAPON; d.attack = 6
		elif id == "axe": d.category = ItemDef.Category.WEAPON; d.attack = 9
		elif id == "leather": d.category = ItemDef.Category.ARMOR; d.armor = 3
		elif id == "charm": d.category = ItemDef.Category.ACCESSORY; d.armor = 1
		elif id == "potion": d.category = ItemDef.Category.CONSUMABLE
		return d

func after_all():
	ItemInstance.base_resolver = Callable()

func _inst(id: String, affixes: Array = []) -> ItemInstance:
	var it := ItemInstance.new(); it.base_id = id; it.affixes = affixes; return it

func test_starts_empty():
	var e := Equipment.new()
	assert_null(e.get_item(Equipment.Slot.WEAPON))
	assert_false(e.is_equipped(Equipment.Slot.WEAPON))
	assert_eq(e.total_attack(), 0)
	assert_eq(e.total_armor(), 0)

func test_equip_weapon_sets_slot_and_attack():
	var e := Equipment.new()
	var displaced := e.equip(_inst("sword"))
	assert_null(displaced)
	assert_eq(e.total_attack(), 6)

func test_equip_displaces_previous_in_same_slot():
	var e := Equipment.new()
	var s1 := _inst("sword")
	var s2 := _inst("axe")
	e.equip(s1)
	var displaced := e.equip(s2)
	assert_eq(displaced, s1)
	assert_eq(e.get_item(Equipment.Slot.WEAPON), s2)
	assert_eq(e.total_attack(), 9)

func test_total_stat_sums_affixes_across_slots():
	var e := Equipment.new()
	e.equip(_inst("sword", [{"id": "of_the_bear", "kind": 1, "mods": {ItemStat.S.MIGHT: 5}}]))
	e.equip(_inst("charm", [{"id": "of_the_bear", "kind": 1, "mods": {ItemStat.S.MIGHT: 3}}]))
	assert_eq(e.total_stat(ItemStat.S.MIGHT), 8)

func test_total_armor_sums_across_slots():
	var e := Equipment.new()
	e.equip(_inst("leather"))
	e.equip(_inst("charm"))
	assert_eq(e.total_armor(), 4)

func test_unequip_returns_item_and_clears_slot():
	var e := Equipment.new()
	var leather := _inst("leather")
	e.equip(leather)
	var removed := e.unequip(Equipment.Slot.ARMOR)
	assert_eq(removed, leather)
	assert_false(e.is_equipped(Equipment.Slot.ARMOR))
	assert_eq(e.total_armor(), 0)

func test_cannot_equip_consumable():
	var e := Equipment.new()
	var potion := _inst("potion")
	assert_false(e.can_equip(potion))
	assert_eq(e.slot_for(potion), -1)

func test_equipped_for_serialization():
	var e := Equipment.new()
	e.equip(_inst("sword"))
	e.equip(_inst("leather"))
	var slots := e.equipped()
	assert_eq(slots[Equipment.Slot.WEAPON].base_id, "sword")
	assert_eq(slots[Equipment.Slot.ARMOR].base_id, "leather")
	assert_false(slots.has(Equipment.Slot.ACCESSORY))
