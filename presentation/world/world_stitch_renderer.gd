class_name WorldStitchRenderer
extends Node3D
# 渲染目前區域 + 一圈鄰區（含對角）的地形+裝飾，各擺在 WorldStitch 全域偏移。
# 以 map_id pooling 重用已建區域節點：跨界只重定位、只建新露出、只清離開
# （避免每次跨界重新 instantiate 持續存在的重 prop，達成無縫）。
# 目前區域用傳入的 live current_map；鄰區用 loader（peek_map）。

var loader: Callable = Callable(MapManager, "peek_map")
# 測試 seam：func(container: Node3D, map: MapData)。預設無效 → 建真 WorldBuilder+ObjectLayer。
var region_builder: Callable = Callable()

var _regions: Dictionary = {}  # map_id -> Node3D 容器

func rebuild(current_map: MapData) -> void:
	if current_map == null:
		return
	var half: int = max(current_map.width, current_map.height)
	var center := Vector2i(current_map.width / 2, current_map.height / 2)
	var placed := WorldStitch.place(current_map, loader, half, center)
	# 新集合的 id
	var keep := {}
	for node in placed:
		keep[node["map"].map_id] = true
	# 清掉離開的區域
	for id in _regions.keys():
		if not keep.has(id):
			_regions[id].free()
			_regions.erase(id)
	# 沿用/新建 + 重定位（沿用者偏移也會隨目前區域改變）
	for node in placed:
		var m: MapData = node["map"]
		var container: Node3D
		if _regions.has(m.map_id):
			container = _regions[m.map_id]
		else:
			container = Node3D.new()
			add_child(container)
			_regions[m.map_id] = container
			_build_content(container, m)
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
