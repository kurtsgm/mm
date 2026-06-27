class_name CombatItems
extends Object

# 戰鬥道具選單來源：背包中「對至少一名隊友可用」的消耗品。
# resolver: Callable(id: String) -> ItemDef（正式為 Callable(ItemCatalog, "get_item")，測試傳假的）。
# 純函式：不依賴 autoload/GameState，可單元測。
static func usable(inventory, party, resolver: Callable) -> Array:
	var out: Array = []
	for stack in inventory.stacks():
		var item: ItemDef = resolver.call(stack["id"])
		if item == null or not item.is_consumable():
			continue
		for m in party.members:
			if ItemEffects.can_use(item, m):
				out.append(item)
				break
	return out
