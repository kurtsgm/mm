class_name ContinentCatalog
extends Object
# 大陸註冊表：載 content/world/continents.json（鏡射 TravelCatalog 的檔案載入）。
# 條目 schema：{id, name, rect}；rect＝世界地圖上的比例座標 [x, y, w, h]（0..1）。

const PATH := "res://content/world/continents.json"

static func load_all() -> Array:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return []
	var root: Variant = JSON.parse_string(f.get_as_text())
	if typeof(root) != TYPE_DICTIONARY:
		return []
	return root.get("continents", [])

static func find(id: String) -> Dictionary:
	for c in load_all():
		if String(c.get("id", "")) == id:
			return c
	return {}
