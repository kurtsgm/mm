extends GutTest

func before_all():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id; d.category = ItemDef.Category.ARMOR
		return d

func after_all():
	ItemInstance.base_resolver = Callable()

func _armor_with_hp(bonus: int) -> ItemInstance:
	var it := ItemInstance.new(); it.base_id = "armor"
	it.affixes = [{"id": "of_vigor", "kind": 1, "mods": {ItemStat.S.HP_MAX: bonus}}]
	return it

func test_equip_moves_instance_from_inventory():
	var c := Character.new(); c.hp = 20; c.hp_max = 20
	var inv := Inventory.new()
	var it := _armor_with_hp(10)
	inv.add_instance(it)
	EquipFlow.equip(c, inv, it)
	assert_eq(inv.instances().size(), 0)
	assert_eq(c.equipment.get_item(Equipment.Slot.ARMOR), it)
	assert_eq(c.effective_hp_max(), 30)

func test_unequip_returns_instance_and_clamps_hp():
	var c := Character.new(); c.hp = 20; c.hp_max = 20
	var inv := Inventory.new()
	var it := _armor_with_hp(10)
	inv.add_instance(it)
	EquipFlow.equip(c, inv, it)
	c.hp = 30                     # 靠裝備上限補到 30
	EquipFlow.unequip(c, inv, Equipment.Slot.ARMOR)
	assert_eq(inv.instances().size(), 1)
	assert_eq(c.hp, 20)          # 卸下後夾回 20
