class_name VendorCatalog
extends Object

const _KINDS := ["goods", "spells", "services"]

static func load_vendor(id: String) -> Dictionary:
	var raw := ContentRegistry.json_entry("vendors", id)
	return raw if _KINDS.has(String(raw.get("kind", ""))) else {}
