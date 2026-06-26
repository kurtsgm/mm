class_name DialogueCatalog
extends Object
# 對話 id → 載 content/dialogues/<id>.json → DialogueData（鏡射 MapManager 的檔案載入）。
# 檔缺/JSON 畸形/圖結構違規 → null。

const DIALOGUES_DIR := "res://content/dialogues"

static func load_dialogue(id: String) -> DialogueData:
	var path := "%s/%s.json" % [DIALOGUES_DIR, id]
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	return DialogueData.parse(raw)
