class_name ContinentCatalog
extends Object
# 大陸註冊表：載 content/world/continents.json（鏡射 TravelCatalog 的檔案載入）。
# 條目 schema：{id, name, rect}；rect＝世界地圖上的比例座標 [x, y, w, h]（0..1）。

static func load_all() -> Array:
	return ContentRegistry.json_entry("world", "continents").get("continents", [])

static func find(id: String) -> Dictionary:
	for c in load_all():
		if String(c.get("id", "")) == id:
			return c
	return {}
