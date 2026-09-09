class_name QuestCatalog
extends Object

static func load_quest(id: String) -> QuestDef:
	var raw := ContentRegistry.json_entry("quests", id)
	return null if raw.is_empty() else QuestDef.parse(raw)
