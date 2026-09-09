class_name ContentRegistry
extends Object

## Gameplay content paths have one owner. Visual/model catalogs remain in presentation.
const MANIFEST := "res://content/registry.json"
static var _manifest: Dictionary = {}

static func _all() -> Dictionary:
	if _manifest.is_empty():
		_manifest = read_json(MANIFEST)
	return _manifest

static func kinds() -> Array:
	return _all().keys()

static func ids(kind: String) -> Array:
	return _all().get(kind, {}).keys()

static func has_entry(kind: String, id: String) -> bool:
	return _all().get(kind, {}).has(id)

static func entry(kind: String, id: String) -> Dictionary:
	return _all().get(kind, {}).get(id, {}).duplicate(true)

static func path_for(kind: String, id: String) -> String:
	return String(entry(kind, id).get("path", ""))

static func resource(kind: String, id: String) -> Resource:
	var path := path_for(kind, id)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)

static func json_entry(kind: String, id: String) -> Dictionary:
	return read_json(path_for(kind, id))

static func read_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	return json.data
