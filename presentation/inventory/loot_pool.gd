class_name LootPool
extends Object

# 列舉 ItemCatalog 中可程序掉落（drop_weight>0）的 base ItemDef。
static func equipment_bases() -> Array:
	var out: Array = []
	for id in ItemCatalog.all_ids():
		var d: ItemDef = ItemCatalog.get_item(id)
		if d != null and d.drop_weight > 0:
			out.append(d)
	return out
