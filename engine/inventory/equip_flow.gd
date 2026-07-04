class_name EquipFlow
extends Object

# 換裝流程（純邏輯）：在 Inventory 實例集合與 Character 裝備欄間搬移，並夾 hp/sp。
static func equip(c: Character, inv: Inventory, inst: ItemInstance) -> void:
	if not c.equipment.can_equip(inst):
		return
	inv.remove_instance(inst)
	var prev: ItemInstance = c.equipment.equip(inst)
	if prev != null:
		inv.add_instance(prev)
	_clamp(c)

static func unequip(c: Character, inv: Inventory, slot: int) -> void:
	var prev: ItemInstance = c.equipment.unequip(slot)
	if prev != null:
		inv.add_instance(prev)
	_clamp(c)

static func _clamp(c: Character) -> void:
	c.hp = mini(c.hp, c.effective_hp_max())
	c.sp = mini(c.sp, c.effective_sp_max())
