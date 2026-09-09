class_name CutsceneCatalog
extends Object

static func load(id: String) -> CutsceneData:
	return load_from(ContentRegistry.path_for("cutscenes", id))

static func load_from(path: String) -> CutsceneData:
	var raw := ContentRegistry.read_json(path)
	return null if raw.is_empty() else CutsceneData.parse(raw)
