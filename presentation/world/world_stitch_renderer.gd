class_name WorldStitchRenderer
extends Node3D
# 渲染目前區域 + 一圈鄰區（含對角）的地形+裝飾，各擺在 WorldStitch 全域偏移。
# 以 map_id pooling 重用已建區域節點：跨界只重定位、只建新露出、只清離開
# （避免每次跨界重新 instantiate 持續存在的重 prop，達成無縫）。
# regions 由 WorldGrid 注入（焦點為 live、鄰圖為 peek，與 grid 同源）。

# 測試 seam：func(container: Node3D, map: MapData)。預設無效 → 建真 WorldBuilder+ObjectLayer。
var region_builder: Callable = Callable()
# 開啟狀態提供者：map_id -> Array[Vector2i]。預設讀 GameState；測試可注入。
var opened_provider: Callable = Callable(GameState, "opened_for")

var _regions: Dictionary = {}  # map_id -> Node3D 容器

func rebuild(regions: Array) -> void:
	# regions = [{map, ox, oy}]（WorldGrid.regions()，單一 stitch 來源）。不再自算第二次 stitch。
	var keep := {}
	for node in regions:
		keep[node["map"].map_id] = true
	# 清掉離開的區域
	for id in _regions.keys():
		if not keep.has(id):
			_regions[id].free()
			_regions.erase(id)
	# 沿用/新建 + 重定位（沿用者偏移也會隨目前區域改變）
	for node in regions:
		var m: MapData = node["map"]
		var container: Node3D
		if _regions.has(m.map_id):
			container = _regions[m.map_id]
		else:
			container = Node3D.new()
			add_child(container)
			_regions[m.map_id] = container
			_build_content(container, m)
		# 必須在 if/else 外（無條件）：沿用的容器在目前區域改變時也要重定位 — 無縫跨界的關鍵不變式。
		container.position = Vector3(
			node["ox"] * GridGeometry.CELL_SIZE, 0.0, node["oy"] * GridGeometry.CELL_SIZE)

func _build_content(container: Node3D, map: MapData) -> void:
	if region_builder.is_valid():
		region_builder.call(container, map)
		return
	var wb := WorldBuilder.new()
	container.add_child(wb)
	wb.build(map)
	var ol := ObjectLayer.new()
	container.add_child(ol)
	ol.build(map)
	var cl := ChestLayer.new()
	container.add_child(cl)
	cl.build(map, _opened_set(map.map_id))

# 開箱當下：只重建「目前區」那一張圖的 ChestLayer（不動其他區、不動地形、不動 pooling）。
func refresh_objects(map: MapData) -> void:
	if map == null or not _regions.has(map.map_id):
		return
	var container: Node3D = _regions[map.map_id]
	for child in container.get_children():
		if child is ChestLayer:
			(child as ChestLayer).build(map, _opened_set(map.map_id))
			return

func _opened_set(map_id: String) -> Dictionary:
	var out: Dictionary = {}
	if opened_provider.is_valid():
		for pos in opened_provider.call(map_id):
			out[pos] = true
	return out
