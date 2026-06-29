class_name DecorationCatalog
extends Object

# model id → 場景。先查明列對照表，查不到再用「約定式」路徑 res://content/models/<id>/<id>.tscn。
# 約定式 fallback 讓各建築/道具模型只要丟一個資料夾就能被引用，不必登記到這裡（零共享檔衝突）。
const _MODELS := {
	"town_oak_ext": "res://content/models/town_oak_ext/town_oak_ext.tscn",
}

static func _convention_path(id: String) -> String:
	return "res://content/models/%s/%s.tscn" % [id, id]

static func has_model(id: String) -> bool:
	if _MODELS.has(id):
		return true
	return FileAccess.file_exists(_convention_path(id))

static func get_scene(id: String) -> PackedScene:
	if _MODELS.has(id):
		return load(_MODELS[id])
	var path := _convention_path(id)
	if FileAccess.file_exists(path):
		return load(path)
	return null
