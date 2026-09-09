class_name ItemUseAction
extends Object

static func use(item: ItemDef, target: Character, inventory: Inventory) -> ActionResult:
	if item == null or inventory == null or not inventory.has(item.id):
		return ActionResult.failure(&"not_owned")
	if not ItemEffects.can_use(item, target):
		return ActionResult.failure(&"invalid_target")
	inventory.remove(item.id, 1)
	return ActionResult.success(ItemEffects.apply(item, target))
