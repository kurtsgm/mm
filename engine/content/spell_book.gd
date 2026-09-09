class_name SpellBook
extends Object

static func has_spell(id: String) -> bool:
	return ContentRegistry.has_entry("spells", id)

static func get_spell(id: String) -> SpellDef:
	return ContentRegistry.resource("spells", id) as SpellDef

static func all_ids() -> Array:
	return ContentRegistry.ids("spells")
