class_name QuestCatalog
extends Object
# 任務 id → 載 content/quests/<id>.json → QuestDef（鏡射 DialogueCatalog）。
# 檔缺 / JSON 畸形 / 定義違規 → null。

const QUESTS_DIR := "res://content/quests"

static func load_quest(id: String) -> QuestDef:
	var path := "%s/%s.json" % [QUESTS_DIR, id]
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	return QuestDef.parse(raw)
