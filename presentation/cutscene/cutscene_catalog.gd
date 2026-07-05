class_name CutsceneCatalog
extends Object
# cutscene id → 載 content/cutscenes/<id>.json → CutsceneData（鏡射 DialogueCatalog）。
# 檔缺/JSON 畸形/step 違規 → null。

const CUTSCENES_DIR := "res://content/cutscenes"

static func load(id: String) -> CutsceneData:
	return load_from("%s/%s.json" % [CUTSCENES_DIR, id])

static func load_from(path: String) -> CutsceneData:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	# 用 JSON.new().parse() 而非靜態 JSON.parse_string()：後者對畸形輸入會 push 引擎錯誤
	# （GUT 會捕捉為 Unexpected Error 使測試失敗）。鏡射 MapImporter「不做 log 副作用」的作法。
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var raw = json.data
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	return CutsceneData.parse(raw)
