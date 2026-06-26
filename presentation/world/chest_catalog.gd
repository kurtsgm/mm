class_name ChestCatalog
extends Object

# style id → 兩態場景路徑（鏡射 DecorationCatalog/ThemeCatalog）。
# 內容期把真模型加進來（換 .tscn 內容或指向 GLB）。
const _STYLES := {
	"chest": {
		"closed": "res://content/models/chest/chest_closed.tscn",
		"open": "res://content/models/chest/chest_open.tscn",
	},
}

static func has_style(id: String) -> bool:
	return _STYLES.has(id)

static func get_scene(id: String, opened: bool) -> PackedScene:
	if not _STYLES.has(id):
		return null
	var key := "open" if opened else "closed"
	return load(_STYLES[id][key])
