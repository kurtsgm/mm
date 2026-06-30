class_name WorldGrid
extends RefCounted

# 統一可遊玩 grid：焦點圖 + 一圈鄰圖（含對角）投影到全域 cell。
# 純邏輯，loader 注入（peek_map）。沿用 WorldStitch.window_for/place → 與 WorldStitchRenderer 座標一致。
# 重疊（well-formed 世界不會發生；WorldStitch 的 visited 已去重）採「第一寫入者勝」確定性處理。

var _owner: Dictionary = {}     # Vector2i(global) -> { "map_id": String, "local": Vector2i }
var _walkable: Dictionary = {}  # Vector2i(global) -> true
var _regions: Array = []        # [{ "map": MapData, "ox": int, "oy": int }]
var _occupants: Dictionary = {}  # Vector2i(global) -> { "kind": String, "dialogue": String }

func _init(focus_map: MapData, loader: Callable) -> void:
	if focus_map == null:
		return
	var win := WorldStitch.window_for(focus_map)
	_regions = WorldStitch.place(focus_map, loader, win["half"], win["center"])
	for region in _regions:
		var m: MapData = region["map"]
		var ox: int = region["ox"]
		var oy: int = region["oy"]
		for y in m.height:
			for x in m.width:
				var g := Vector2i(x + ox, y + oy)
				if _owner.has(g):
					continue   # 第一寫入者勝（BFS 順序，確定性）
				var local := Vector2i(x, y)
				_owner[g] = { "map_id": m.map_id, "local": local }
				if MapBuilder.is_walkable_type(m.get_tile(local)):
					_walkable[g] = true
		for q in m.quest_givers:
			var qg: Vector2i = q["pos"] + Vector2i(ox, oy)
			if _occupants.has(qg):
				continue   # 第一寫入者勝（與 _owner 同確定性規則）
			_occupants[qg] = {"kind": "questgiver", "dialogue": String(q["dialogue"])}
			_walkable.erase(qg)   # NPC 實心擋路：占用格不可走（牆格 erase 為 no-op）

func is_walkable(global: Vector2i) -> bool:
	return _walkable.has(global)

func occupant_at(global: Vector2i) -> Dictionary:
	return _occupants.get(global, {})

func resolve(global: Vector2i) -> Dictionary:
	return _owner.get(global, {})

func regions() -> Array:
	return _regions
