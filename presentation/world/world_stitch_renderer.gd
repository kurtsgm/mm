class_name WorldStitchRenderer
extends Node3D
# 靜態地形/裝飾依 map_id pooling；動態寶箱依明確注入的 WorldSnapshot 同步。
# rebuild 與讀檔共用一條路徑：所有保留區域（含鄰圖）都同步，不能只刷新焦點圖。

# 靜態建構 seam：func(container: Node3D, map: MapData)。未注入時建 WorldBuilder + ObjectLayer。
var region_builder: Callable = Callable()

var _regions: Dictionary = {}  # map_id -> Node3D 靜態容器
var _maps: Dictionary = {}     # 當前可見區域的完整地圖定義
var _chests: Dictionary = {}   # map_id -> ChestLayer
var _opened: Dictionary = {}  # 已呈現的開箱集合，與 GameState 無共享參照

func rebuild(regions: Array, state: WorldSnapshot) -> void:
	var keep := {}
	for region in regions:
		keep[region["map"].map_id] = true
	for id in _regions.keys():
		if not keep.has(id):
			_regions[id].free()
			_regions.erase(id)
			_maps.erase(id)
			_chests.erase(id)
			_opened.erase(id)
	for region in regions:
		var map: MapData = region["map"]
		var container: Node3D
		if _regions.has(map.map_id):
			container = _regions[map.map_id]
		else:
			container = Node3D.new()
			add_child(container)
			_regions[map.map_id] = container
			_build_static(container, map)
			var chests := ChestLayer.new()
			container.add_child(chests)
			_chests[map.map_id] = chests
		_maps[map.map_id] = map
		container.position = Vector3(
			region["ox"] * GridGeometry.CELL_SIZE, 0.0, region["oy"] * GridGeometry.CELL_SIZE)
	sync_state(state)

func _build_static(container: Node3D, map: MapData) -> void:
	if region_builder.is_valid():
		region_builder.call(container, map)
		return
	var wb := WorldBuilder.new()
	container.add_child(wb)
	wb.build(map)
	var ol := ObjectLayer.new()
	container.add_child(ol)
	ol.build(map)

# 同步全部可見區，但只有狀態改變的 ChestLayer 重建；地形、建築與未變寶箱不動。
func sync_state(state: WorldSnapshot) -> void:
	for id in _maps:
		var opened := state.opened_for(id)
		if _opened.has(id) and _opened[id] == opened:
			continue
		_chests[id].build(_maps[id], opened)
		_opened[id] = opened
