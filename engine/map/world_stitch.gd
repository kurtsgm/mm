class_name WorldStitch
extends Object

# 以隊伍為中心的視窗內，從當前圖出發 BFS 走 neighbors，把相交的地圖（含對角）
# 置入全域偏移。回傳 [{ "map": MapData, "ox": int, "oy": int }, …]。
# loader: Callable(String)->MapData（注入；未知/不存在回 null）。
# 對邊對齊沿用 MapTransitions：EAST 子圖貼當前圖右、WEST 貼左（用鄰圖寬）、
# SOUTH 貼下、NORTH 貼上（用鄰圖高）。視窗矩形 [center±half]（含端點）相交才置入。
static func place(origin_map: MapData, loader: Callable, half: int, center: Vector2i) -> Array:
	var placed: Array = []
	if origin_map == null:
		return placed
	var min_x := center.x - half
	var max_x := center.x + half
	var min_y := center.y - half
	var max_y := center.y + half
	var visited := { origin_map.map_id: true }
	placed.append({ "map": origin_map, "ox": 0, "oy": 0 })
	var i := 0
	while i < placed.size():
		var node: Dictionary = placed[i]
		i += 1
		var m: MapData = node["map"]
		var ox: int = node["ox"]
		var oy: int = node["oy"]
		for dir in [GridDirection.Dir.NORTH, GridDirection.Dir.EAST, GridDirection.Dir.SOUTH, GridDirection.Dir.WEST]:
			if not m.has_neighbor(dir):
				continue
			var nid: String = m.get_neighbor(dir)
			if visited.has(nid):
				continue
			var nb: MapData = loader.call(nid)
			if nb == null:
				continue
			var nox := ox
			var noy := oy
			match dir:
				GridDirection.Dir.EAST: nox = ox + m.width
				GridDirection.Dir.WEST: nox = ox - nb.width
				GridDirection.Dir.SOUTH: noy = oy + m.height
				GridDirection.Dir.NORTH: noy = oy - nb.height
			# 子圖全域矩形 [nox..nox+nb.width-1] × [noy..noy+nb.height-1] 與視窗相交？
			if nox > max_x or nox + nb.width - 1 < min_x or noy > max_y or noy + nb.height - 1 < min_y:
				continue
			visited[nid] = true
			placed.append({ "map": nb, "ox": nox, "oy": noy })
	return placed
