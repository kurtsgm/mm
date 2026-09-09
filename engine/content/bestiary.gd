class_name Bestiary
extends Object

static func all_ids() -> Array:
	return ContentRegistry.ids("encounters")

static func group_defs_for(id: String) -> Array[MonsterDef]:
	var out: Array[MonsterDef] = []
	var def := ContentRegistry.resource("encounters", id) as MonsterDef
	if def == null:
		return out
	for i in int(ContentRegistry.entry("encounters", id).get("count", 0)):
		out.append(def)
	return out
