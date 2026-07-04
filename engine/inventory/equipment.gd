class_name Equipment
extends RefCounted

# 每名角色的裝備欄：slot(int) -> ItemInstance。WEAPON/ARMOR/ACCESSORY 與 ItemDef.Category 0/1/2 一比一。
enum Slot { WEAPON = 0, ARMOR = 1, ACCESSORY = 2 }
const SLOT_COUNT := 3

var _slots: Dictionary = {}   # Slot(int) -> ItemInstance

func get_item(slot: int) -> ItemInstance:
	return _slots.get(slot, null)

func is_equipped(slot: int) -> bool:
	return _slots.has(slot)

func can_equip(item: ItemInstance) -> bool:
	if item == null:
		return false
	var def := item.base_def()
	return def != null and def.is_equippable()

func slot_for(item: ItemInstance) -> int:
	# 可裝備類別（0/1/2）即為對應欄位；消耗品/空 → -1
	if not can_equip(item):
		return -1
	return item.base_def().category

func equip(item: ItemInstance) -> ItemInstance:
	# 裝上 item，回傳被換下的舊件（沒有則 null）。呼叫端須先 can_equip()。
	var slot := slot_for(item)
	if slot == -1:
		return null
	var prev: ItemInstance = _slots.get(slot, null)
	_slots[slot] = item
	return prev

func unequip(slot: int) -> ItemInstance:
	var prev: ItemInstance = _slots.get(slot, null)
	_slots.erase(slot)
	return prev

func total_attack() -> int:
	var t := 0
	for s in _slots:
		t += _slots[s].total_attack()
	return t

func total_armor() -> int:
	var t := 0
	for s in _slots:
		t += _slots[s].total_armor()
	return t

func total_stat(stat: int) -> int:
	var t := 0
	for s in _slots:
		t += _slots[s].total_stat(stat)
	return t

func equipped() -> Dictionary:
	# slot(int) -> ItemInstance，供序列化
	return _slots.duplicate()
