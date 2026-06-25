class_name Inventory
extends RefCounted

# 共享隊伍背包：以 id 計數的多重集合，每個 distinct id 一個堆疊 {"id","count"}。
# 引擎純邏輯：只認 id 與數量，不載入 ItemDef（內容解析交給呈現層的 ItemCatalog）。
var _stacks: Array = []   # Array[Dictionary]

func add(item_id: String, count: int = 1) -> void:
	if item_id == "" or count <= 0:
		return
	for s in _stacks:
		if s["id"] == item_id:
			s["count"] += count
			return
	_stacks.append({"id": item_id, "count": count})

func remove(item_id: String, count: int = 1) -> int:
	if count <= 0:
		return 0
	for i in _stacks.size():
		var s: Dictionary = _stacks[i]
		if s["id"] == item_id:
			var removed: int = mini(count, s["count"])
			s["count"] -= removed
			if s["count"] <= 0:
				_stacks.remove_at(i)
			return removed
	return 0

func count_of(item_id: String) -> int:
	for s in _stacks:
		if s["id"] == item_id:
			return s["count"]
	return 0

func has(item_id: String) -> bool:
	return count_of(item_id) > 0

func is_empty() -> bool:
	return _stacks.is_empty()

func stacks() -> Array:
	var out: Array = []
	for s in _stacks:
		out.append({"id": s["id"], "count": s["count"]})
	return out

func load_stacks(arr) -> void:
	_stacks = []
	for s in arr:
		add(String(s.get("id", "")), int(s.get("count", 0)))
