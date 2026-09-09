class_name CharacterItemsTab
extends Object

# 裝備槽 + 全隊共用背包的顯示與動作。動作透過 Equipment / ItemEffects / Inventory；回事件字串。

const _SLOTS := [Equipment.Slot.WEAPON, Equipment.Slot.ARMOR, Equipment.Slot.ACCESSORY]

static func rows(member: Character, inventory) -> Array:
	var out: Array = []
	for slot in _SLOTS:
		var it: ItemInstance = member.equipment.get_item(slot)
		var row: Dictionary = {
			"kind": "equip", "slot": slot,
			"name": (it.display_name() if it != null else "-"),
			"stat": (_equip_stat(slot, it) if it != null else ""),
		}
		if it != null:
			row["quality"] = it.quality
		out.append(row)
	# 背包：可堆疊消耗品（id 列）
	for s in inventory.stacks():
		var item := ItemCatalog.get_item(String(s["id"]))
		var nm := item.display_name if item != null else String(s["id"])
		var cat := int(item.category) if item != null else int(ItemDef.Category.CONSUMABLE)
		out.append({"kind": "item", "id": String(s["id"]), "count": int(s["count"]), "name": nm, "category": cat})
	# 背包：不可堆疊裝備實例（inst 列，無 id）
	for inst in inventory.instances():
		var idef: ItemDef = inst.base_def()
		out.append({
			"kind": "item", "inst": inst, "count": 1,
			"name": inst.display_name(),
			"category": (int(idef.category) if idef != null else int(ItemDef.Category.WEAPON)),
			"quality": inst.quality,
		})
	return out

# 已裝備實例的關鍵數值字串：武器→總攻擊、防具→總防禦、飾品→有什麼顯示什麼；皆無則空字串。
static func _equip_stat(slot: int, it: ItemInstance) -> String:
	var atk := it.total_attack()
	var arm := it.total_armor()
	match slot:
		Equipment.Slot.WEAPON:
			return "+%d" % atk if atk != 0 else ""
		Equipment.Slot.ARMOR:
			return "+%d" % arm if arm != 0 else ""
		Equipment.Slot.ACCESSORY:
			if atk != 0:
				return "+%d" % atk
			if arm != 0:
				return "+%d" % arm
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
	# 裝備槽：卸下 → 走 EquipFlow（推回 instances() 並夾 hp/sp）
	if String(row.get("kind", "")) == "equip":
		var slot := int(row["slot"])
		if member.equipment.is_equipped(slot):
			var prev: ItemInstance = member.equipment.get_item(slot)
			EquipFlow.unequip(member, inventory, slot)
			events.append("%s 卸下了 %s。" % [member.name, prev.display_name()])
		return events
	# 背包裝備實例：裝備 → 走 EquipFlow（換下者自動回背包）
	if row.has("inst"):
		var inst: ItemInstance = row["inst"]
		if member.equipment.can_equip(inst):
			EquipFlow.equip(member, inventory, inst)
			events.append("%s 裝備了 %s。" % [member.name, inst.display_name()])
		return events
	# 背包消耗品：使用（不變）
	var item := ItemCatalog.get_item(String(row["id"]))
	if item == null:
		return events
	if item.is_consumable():
		events = ItemUseAction.use(item, member, inventory).events
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
