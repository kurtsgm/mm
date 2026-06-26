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

# 假 region_builder：在容器放一個帶 map_id 名的標記節點，不建真 GridMap。
func _fake_build(container: Node3D, map: MapData) -> void:
	var marker := Node3D.new()
	marker.name = "marker_" + map.map_id
	container.add_child(marker)

func _renderer() -> WorldStitchRenderer:
	var r := WorldStitchRenderer.new()
	r.loader = Callable(self, "_loader")
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
	r.rebuild(a)
	assert_eq(r.get_child_count(), 1)
	assert_eq((r.get_child(0) as Node3D).position, Vector3.ZERO)

func test_east_neighbor_container_offset():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var r := _renderer()
	r.rebuild(a)
	var e_container := _container_with_marker(r, "marker_e")
	assert_not_null(e_container)
	assert_eq(e_container.position, Vector3(5 * GridGeometry.CELL_SIZE, 0, 0))

func test_pooling_reuses_region_node_across_rebuild():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var r := _renderer()
	r.rebuild(a)
	var a1 := _container_with_marker(r, "marker_a")
	r.rebuild(a)   # 同一 current 再 rebuild
	var a2 := _container_with_marker(r, "marker_a")
	assert_eq(a1, a2, "沿用同一節點實例，未重建")

func test_reused_container_repositioned_when_current_region_changes():
	# 沿用的容器在 current 改變時必須重定位（位置賦值不可移進 else）。
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var r := _renderer()
	r.rebuild(a)   # a 為 current，在原點
	var a1 := _container_with_marker(r, "marker_a")
	assert_not_null(a1)
	assert_eq(a1.position, Vector3.ZERO, "a 為 current 時在原點")
	r.rebuild(e)   # e 為 current → a 變成西鄰，容器沿用但須重定位
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
	r.rebuild(a)
	assert_gt(r.get_child_count(), 1)
	r.rebuild(far)   # far 無鄰 → a/e 應被 free
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
	r.loader = Callable(self, "_loader")
	add_child_autofree(r)
	r.rebuild(a)
	assert_eq(r.get_child_count(), 1)
	var container: Node3D = r.get_child(0)
	assert_eq(container.position, Vector3.ZERO)
	assert_true(container.get_child(0) is WorldBuilder, "容器含 WorldBuilder")
	assert_true(container.get_child(1) is ObjectLayer, "容器含 ObjectLayer")
