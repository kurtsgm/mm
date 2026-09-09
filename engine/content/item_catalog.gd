class_name ItemCatalog
extends Object

static func has_item(id: String) -> bool:
	return ContentRegistry.has_entry("items", id)

static func get_item(id: String) -> ItemDef:
	return ContentRegistry.resource("items", id) as ItemDef

static func all_ids() -> Array:
	return ContentRegistry.ids("items")

static func install_resolver() -> void:
	ItemInstance.base_resolver = Callable(ItemCatalog, "get_item")
