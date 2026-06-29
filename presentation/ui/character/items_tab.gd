class_name CharacterItemsTab
extends Object

# 裝備槽 + 全隊共用背包的顯示與動作。動作透過 Equipment / ItemEffects / Inventory；回事件字串。

const _SLOTS := [Equipment.Slot.WEAPON, Equipment.Slot.ARMOR, Equipment.Slot.ACCESSORY]

static func rows(member: Character, inventory) -> Array:
	var out: Array = []
	for slot in _SLOTS:
		var it: ItemDef = member.equipment.get_item(slot)
		out.append({
			"kind": "equip", "slot": slot,
			"name": (it.display_name if it != null else "-"),
			"stat": (_equip_stat(slot, it) if it != null else ""),
		})
	for s in inventory.stacks():
		var item := ItemCatalog.get_item(String(s["id"]))
		var nm := item.display_name if item != null else String(s["id"])
		var cat := int(item.category) if item != null else int(ItemDef.Category.CONSUMABLE)
		out.append({"kind": "item", "id": String(s["id"]), "count": int(s["count"]), "name": nm, "category": cat})
	return out

# 已裝備道具的關鍵數值字串：武器→攻擊、防具→防禦、飾品→有什麼顯示什麼；皆無則空字串。
static func _equip_stat(slot: int, it: ItemDef) -> String:
	match slot:
		Equipment.Slot.WEAPON:
			return "+%d" % it.attack if it.attack != 0 else ""
		Equipment.Slot.ARMOR:
			return "+%d" % it.armor if it.armor != 0 else ""
		Equipment.Slot.ACCESSORY:
			if it.attack != 0:
				return "+%d" % it.attack
			if it.armor != 0:
				return "+%d" % it.armor
	return ""

static func lines(rows_: Array, cursor: int) -> Array:
	var out: Array = ["== 裝備 =="]
	for i in rows_.size():
		if String(rows_[i]["kind"]) != "equip":
			continue
		var mark := "> " if i == cursor else "  "
		out.append("%s%s：%s" % [mark, _slot_label(int(rows_[i]["slot"])), String(rows_[i]["name"])])
	out.append("== 背包 ==")
	var any := false
	for i in rows_.size():
		if String(rows_[i]["kind"]) != "item":
			continue
		any = true
		var mark := "> " if i == cursor else "  "
		out.append("%s%s ×%d" % [mark, String(rows_[i]["name"]), int(rows_[i]["count"])])
	if not any:
		out.append("（空）")
	return out

static func activate(row: Dictionary, member: Character, inventory) -> Array:
	var events: Array = []
	if String(row.get("kind", "")) == "equip":
		var slot := int(row["slot"])
		if member.equipment.is_equipped(slot):
			var removed := member.equipment.unequip(slot)
			inventory.add(removed.id, 1)
			events.append("%s 卸下了 %s。" % [member.name, removed.display_name])
		return events
	var item := ItemCatalog.get_item(String(row["id"]))
	if item == null:
		return events
	if item.is_consumable():
		events = ItemEffects.apply(item, member)
		if not events.is_empty():
			inventory.remove(item.id, 1)
		return events
	if member.equipment.can_equip(item):
		var displaced := member.equipment.equip(item)
		inventory.remove(item.id, 1)
		if displaced != null:
			inventory.add(displaced.id, 1)
		events.append("%s 裝備了 %s。" % [member.name, item.display_name])
	return events

static func _slot_label(slot: int) -> String:
	match slot:
		Equipment.Slot.WEAPON:
			return "武器"
		Equipment.Slot.ARMOR:
			return "防具"
		Equipment.Slot.ACCESSORY:
			return "飾品"
	return "?"
