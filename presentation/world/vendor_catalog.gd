class_name VendorCatalog
extends Object
# vendor id → 載 content/vendors/<id>.json → Dictionary（鏡射 DialogueCatalog 的檔案載入）。
# 檔缺/JSON 畸形/kind 違規 → {}（呼叫端以 is_empty() 判斷）。

const VENDORS_DIR := "res://content/vendors"
const _KINDS := ["goods", "spells", "services"]

static func load_vendor(id: String) -> Dictionary:
	var path := "%s/%s.json" % [VENDORS_DIR, id]
	if not FileAccess.file_exists(path):
		return {}
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	if not raw.has("kind") or not _KINDS.has(String(raw["kind"])):
		return {}
	return raw
