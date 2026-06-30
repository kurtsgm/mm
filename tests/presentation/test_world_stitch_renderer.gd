extends GutTest

var _world := {}

func _map(id: String, w: int, h: int, neighbors := {}) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.neighbors = neighbors
	return m

func _loader(id: String) -> MapData:
	return _world.get(id, null)

func _regions_for(current: MapData) -> Array:
	var win := WorldStitch.window_for(current)
	return WorldStitch.place(current, Callable(self, "_loader"), win["half"], win["center"])

# 假 region_builder：在容器放一個帶 map_id 名的標記節點，不建真 GridMap。
func _fake_build(container: Node3D, map: MapData) -> void:
	var marker := Node3D.new()
	marker.name = "marker_" + map.map_id
	container.add_child(marker)

func _renderer() -> WorldStitchRenderer:
	var r := WorldStitchRenderer.new()
	r.region_builder = Callable(self, "_fake_build")
	add_child_autofree(r)
	return r

func _container_with_marker(r: WorldStitchRenderer, marker_name: String) -> Node3D:
	for c in r.get_children():
		if c.has_node(marker_name):
			return c
	return null

func test_single_map_one_container_at_origin():
	var a := _map("a", 5, 5)
	_world = { "a": a }
	var r := _renderer()
	r.rebuild(_regions_for(a))
	assert_eq(r.get_child_count(), 1)
	assert_eq((r.get_child(0) as Node3D).position, Vector3.ZERO)

func test_east_neighbor_container_offset():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var r := _renderer()
	r.rebuild(_regions_for(a))
	var e_container := _container_with_marker(r, "marker_e")
	assert_not_null(e_container)
	assert_eq(e_container.position, Vector3(5 * GridGeometry.CELL_SIZE, 0, 0))

func test_pooling_reuses_region_node_across_rebuild():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var r := _renderer()
	r.rebuild(_regions_for(a))
	var a1 := _container_with_marker(r, "marker_a")
	r.rebuild(_regions_for(a))   # 同一 current 再 rebuild
	var a2 := _container_with_marker(r, "marker_a")
	assert_eq(a1, a2, "沿用同一節點實例，未重建")

func test_reused_container_repositioned_when_current_region_changes():
	# 沿用的容器在 current 改變時必須重定位（位置賦值不可移進 else）。
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var r := _renderer()
	r.rebuild(_regions_for(a))   # a 為 current，在原點
	var a1 := _container_with_marker(r, "marker_a")
	assert_not_null(a1)
	assert_eq(a1.position, Vector3.ZERO, "a 為 current 時在原點")
	r.rebuild(_regions_for(e))   # e 為 current → a 變成西鄰，容器沿用但須重定位
	var a2 := _container_with_marker(r, "marker_a")
	assert_eq(a1, a2, "沿用同一容器實例（pooled，未重建）")
	assert_eq(a2.position, Vector3(-a.width * GridGeometry.CELL_SIZE, 0, 0),
		"沿用的容器在 current 改變後重定位到西鄰偏移")

func test_pooling_frees_departed_region():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	var far := _map("far", 5, 5)
	_world = { "a": a, "e": e, "far": far }
	var r := _renderer()
	r.rebuild(_regions_for(a))
	assert_gt(r.get_child_count(), 1)
	r.rebuild(_regions_for(far))   # far 無鄰 → a/e 應被 free
	assert_eq(r.get_child_count(), 1, "離開的區域被清掉")
	assert_not_null(_container_with_marker(r, "marker_far"))

func test_default_path_builds_real_worldbuilder_and_objectlayer():
	# 不注入 region_builder → 走真實建構（default 程序主題、無外部素材）。
	var a := _map("a", 3, 3)
	a.theme_id = "default"
	var t := PackedInt32Array()
	t.resize(9)        # 全 0 = FLOOR
	a.tiles = t
	_world = { "a": a }
	var r := WorldStitchRenderer.new()
	add_child_autofree(r)
	r.rebuild(_regions_for(a))
	assert_eq(r.get_child_count(), 1)
	var container: Node3D = r.get_child(0)
	assert_eq(container.position, Vector3.ZERO)
	assert_true(container.get_child(0) is WorldBuilder, "容器含 WorldBuilder")
	assert_true(container.get_child(1) is ObjectLayer, "容器含 ObjectLayer")

func _no_opened(_map_id: String) -> Array:
	return []

func _chest_layer_of(container: Node3D) -> ChestLayer:
	for c in container.get_children():
		if c is ChestLayer:
			return c
	return null

func test_default_path_builds_chest_layer():
	var a := _map("a", 3, 3)
	a.theme_id = "default"
	var t := PackedInt32Array()
	t.resize(9)
	a.tiles = t
	_world = { "a": a }
	var r := WorldStitchRenderer.new()
	r.opened_provider = Callable(self, "_no_opened")
	add_child_autofree(r)
	r.rebuild(_regions_for(a))
	var container: Node3D = r.get_child(0)
	assert_true(container.get_child(2) is ChestLayer, "容器含 ChestLayer（第三層）")

func test_refresh_objects_rebuilds_chest_layer():
	var a := _map("a", 3, 3)
	a.theme_id = "default"
	var t := PackedInt32Array()
	t.resize(9)
	a.tiles = t
	a.objects = [{"pos": Vector2i(1, 1), "items": [], "gold": 0, "model": "chest"}]
	_world = { "a": a }
	var r := WorldStitchRenderer.new()
	r.opened_provider = Callable(self, "_no_opened")
	add_child_autofree(r)
	r.rebuild(_regions_for(a))
	var cl := _chest_layer_of(r.get_child(0))
	assert_not_null(cl)
	assert_eq(cl.get_child_count(), 1, "一個寶箱物件 → 一個節點")
	# 模擬 stale：清空後 refresh 應重建
	for c in cl.get_children():
		cl.remove_child(c)
		c.free()
	assert_eq(cl.get_child_count(), 0)
	r.refresh_objects(a)
	assert_eq(cl.get_child_count(), 1, "refresh_objects 重建目標區 ChestLayer")
