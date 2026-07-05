class_name AudioCatalog
extends Object

const TRACKS_PATH := "res://content/audio/tracks.json"
const SFX_PATH := "res://content/audio/sfx.json"

static func _load_registry(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var root: Variant = JSON.parse_string(f.get_as_text())
	if typeof(root) != TYPE_DICTIONARY:
		return {}
	return root

static func track_entry(id: String) -> Dictionary:
	var e: Variant = _load_registry(TRACKS_PATH).get(id)
	return e if typeof(e) == TYPE_DICTIONARY else {}

static func sfx_entry(id: String) -> Dictionary:
	var e: Variant = _load_registry(SFX_PATH).get(id)
	return e if typeof(e) == TYPE_DICTIONARY else {}
