class_name DecorationCatalog
extends Object

# model id → GLB（或 .tscn）路徑（鏡射 ThemeCatalog/Bestiary/ItemCatalog）。
# 內容期把真模型加進來：例如 "town_oak_ext": "res://content/models/town_oak_ext/town.glb"。
const _MODELS := {
	"town_oak_ext": "res://content/models/town_oak_ext/town_oak_ext.tscn",
}

static func has_model(id: String) -> bool:
	return _MODELS.has(id)

static func get_scene(id: String) -> PackedScene:
	if _MODELS.has(id):
		return load(_MODELS[id])
	return null
