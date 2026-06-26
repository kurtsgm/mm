extends GutTest

class FakeCatalog extends RefCounted:
	var scene: PackedScene
	var calls: Array = []   # [{id, opened}]
	func get_scene(id: String, opened: bool) -> PackedScene:
		calls.append({"id": id, "opened": opened})
		return scene

func _make_scene() -> PackedScene:
	var root := Node3D.new()
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps

func _map_with(objs: Array) -> MapData:
	var m := MapData.new()
	m.width = 5
	m.height = 5
	m.objects = objs
	return m

func _obj(pos: Vector2i) -> Dictionary:
	return {"pos": pos, "items": [], "gold": 0, "model": "chest"}

func test_one_node_per_object():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_obj(Vector2i(1, 1)), _obj(Vector2i(3, 1))]), {}, cat)
	assert_eq(layer.get_child_count(), 2)

func test_positions_node_at_cell():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_obj(Vector2i(2, 1))]), {}, cat)
	assert_eq((layer.get_child(0) as Node3D).position, GridGeometry.cell_to_world(Vector2i(2, 1)))

func test_opened_cell_requests_open_scene():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_obj(Vector2i(1, 1))]), {Vector2i(1, 1): true}, cat)
	assert_true(cat.calls[0]["opened"])

func test_closed_cell_requests_closed_scene():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_obj(Vector2i(1, 1))]), {}, cat)
	assert_false(cat.calls[0]["opened"])

func test_clears_previous_children():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_obj(Vector2i(0, 0))]), {}, cat)
	layer.build(_map_with([_obj(Vector2i(1, 1))]), {}, cat)
	assert_eq(layer.get_child_count(), 1)

func test_skips_unknown_model():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = null
	layer.build(_map_with([_obj(Vector2i(0, 0))]), {}, cat)
	assert_eq(layer.get_child_count(), 0)
