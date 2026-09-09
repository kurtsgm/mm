class_name DialogueCatalog
extends Object

static func load_dialogue(id: String) -> DialogueData:
	var raw := ContentRegistry.json_entry("dialogues", id)
	return null if raw.is_empty() else DialogueData.parse(raw)
