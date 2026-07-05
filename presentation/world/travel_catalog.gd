class_name TravelCatalog
extends Object
# 旅行網節點目錄：載 content/world/travel_network.json（鏡射 VendorCatalog 的檔案載入）。
# 節點 schema：{id, name, continent, map, entry, unlock}；unlock == "" ＝ 預設解鎖。

const PATH := "res://content/world/travel_network.json"

static func load_network() -> Array:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return []
	var root: Variant = JSON.parse_string(f.get_as_text())
	if typeof(root) != TYPE_DICTIONARY:
		return []
	return root.get("nodes", [])

static func node_entry(node_id: String) -> Dictionary:
	for n in load_network():
		if String(n.get("id", "")) == node_id:
			return n
	return {}

# 已解鎖且非目前節點的目的地。unlock == "" ＝ 預設解鎖。
static func unlocked_destinations(state, current_node_id: String) -> Array:
	var out: Array = []
	for n in load_network():
		if String(n.get("id", "")) == current_node_id:
			continue
		var unlock := String(n.get("unlock", ""))
		if unlock == "" or state.has_flag(unlock):
			out.append(n)
	return out
