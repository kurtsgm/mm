class_name NeighborMonsters
extends Object

# 蒐集「鄰接拼接地圖」的怪，回全域 cell 的靜態顯示列（current map 的怪由 _monster_layer 另畫）。
# 純邏輯：loader/is_defeated/saved_provider 皆注入。movement 不在此（鄰圖怪只顯示、不追）。
# 重用 WorldStitch（區域偏移）+ OverworldMonsters（排除 defeated、套存檔位置、live 格式）。
static func collect(current_map: MapData, loader: Callable, is_defeated: Callable, saved_provider: Callable) -> Array:
	var out: Array = []
	if current_map == null:
		return out
	var half: int = max(current_map.width, current_map.height)
	var center := Vector2i(current_map.width / 2, current_map.height / 2)
	var placed := WorldStitch.place(current_map, loader, half, center)
	for region in placed:
		var m: MapData = region["map"]
		if m == null or m.map_id == current_map.map_id:
			continue   # current map 的怪由別的層畫
		var offset := Vector2i(int(region["ox"]), int(region["oy"]))
		var om := OverworldMonsters.new()
		om.init_from_map(m, is_defeated)
		var saved = saved_provider.call(m.map_id)
		if typeof(saved) != TYPE_DICTIONARY:
			saved = {}
		om.apply_saved(saved)
		for row in om.live():
			out.append({
				"uid": row["uid"],
				"group": row["group"],
				"cell": row["cell"] + offset,
				"state": row["state"],
			})
	return out
