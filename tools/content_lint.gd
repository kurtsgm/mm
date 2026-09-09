class_name ContentLint
extends Object

## Verify the registry and cross-content dependencies before entering gameplay.
static func run() -> Array:
	var errors: Array = []
	for kind in ContentRegistry.kinds():
		for id in ContentRegistry.ids(kind):
			var path := ContentRegistry.path_for(kind, id)
			if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
				errors.append("%s/%s: missing %s" % [kind, id, path])
				continue
			match kind:
				"items":
					var item := ItemCatalog.get_item(id)
					if item == null or item.id != id:
						errors.append("items/%s: invalid definition or ID" % id)
				"spells":
					var spell := SpellBook.get_spell(id)
					if spell == null or spell.id != id or spell.sp_cost < 0:
						errors.append("spells/%s: invalid definition" % id)
				"encounters":
					if Bestiary.group_defs_for(id).is_empty():
						errors.append("encounters/%s: invalid group" % id)
				"quests":
					var quest := QuestCatalog.load_quest(id)
					if quest == null or quest.id != id:
						errors.append("quests/%s: invalid definition" % id)
				"dialogues":
					var dialogue := DialogueCatalog.load_dialogue(id)
					if dialogue == null or dialogue.id != id:
						errors.append("dialogues/%s: invalid definition" % id)
					else:
						for node in dialogue.nodes.values():
							for choice in node.get("choices", []):
								check_effects(choice.get("effects", []), "dialogue/%s" % id, errors)
				"cutscenes":
					var cutscene := CutsceneCatalog.load(id)
					if cutscene == null or cutscene.id != id:
						errors.append("cutscenes/%s: invalid definition" % id)
					else:
						for step in cutscene.steps:
							if step["type"] == "dialogue":
								check_reference("dialogues", step["dialogue"], "cutscene/%s" % id, errors)
							elif step["type"] == "effects":
								check_effects(step["effects"], "cutscene/%s" % id, errors)
				"vendors":
					var vendor := VendorCatalog.load_vendor(id)
					if vendor.is_empty():
						errors.append("vendors/%s: invalid definition" % id)
					else:
						for item in vendor.get("stock", []):
							check_reference("items", item, "vendor/%s" % id, errors)
						for spell in vendor.get("spells", []):
							check_reference("spells", spell, "vendor/%s" % id, errors)
				"maps":
					_check_map(id, path, errors)
	for node in TravelCatalog.load_network():
		check_destination(String(node.get("map", "")), String(node.get("entry", "")), "travel/%s" % node.get("id", ""), errors)
	return errors

static func check_reference(kind: String, id: String, source: String, errors: Array) -> void:
	if not ContentRegistry.has_entry(kind, id):
		errors.append("%s: missing %s/%s" % [source, kind, id])

static func check_destination(map_id: String, entry: String, source: String, errors: Array) -> void:
	check_reference("maps", map_id, source, errors)
	var path := ContentRegistry.path_for("maps", map_id)
	if path == "" or not FileAccess.file_exists(path):
		return
	var map := MapImporter.parse(FileAccess.get_file_as_string(path))
	if map == null or not map.has_entry(entry):
		errors.append("%s: missing entry %s/%s" % [source, map_id, entry])

static func check_effects(effects: Array, source: String, errors: Array) -> void:
	for effect in effects:
		match String(effect.get("op", "")):
			"give", "take": check_reference("items", String(effect.get("item", "")), source, errors)
			"accept_quest", "advance_quest": check_reference("quests", String(effect.get("quest", "")), source, errors)
			"set_flag", "clear_flag":
				if String(effect.get("flag", "")) == "":
					errors.append("%s: empty flag" % source)
			"gold": pass
			_: errors.append("%s: unsupported effect %s" % [source, effect.get("op", "")])

static func _check_map(id: String, path: String, errors: Array) -> void:
	var map := MapImporter.parse(FileAccess.get_file_as_string(path))
	if map == null:
		errors.append("maps/%s: invalid definition" % id)
		return
	for neighbor in map.neighbors.values():
		check_reference("maps", neighbor, "map/%s" % id, errors)
	for group in map.encounters.values():
		check_reference("encounters", group, "map/%s" % id, errors)
	for link in map.links.values():
		check_destination(link["map"], link["entry"], "map/%s" % id, errors)
	for scene in map.scenes:
		var kind := "cutscenes" if scene.has("cutscene") else "dialogues"
		check_reference(kind, scene.get("cutscene", scene.get("dialogue", "")), "map/%s" % id, errors)
	for npc in map.quest_givers:
		check_reference("dialogues", npc["dialogue"], "map/%s" % id, errors)
	for vendor in map.vendors:
		check_reference("vendors", vendor["id"], "map/%s" % id, errors)
	for chest in map.objects:
		for item in chest.get("items", []):
			check_reference("items", item, "map/%s" % id, errors)
