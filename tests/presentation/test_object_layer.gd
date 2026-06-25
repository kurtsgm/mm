extends GutTest

class FakeCatalog extends RefCounted:
	var scene: PackedScene
	func get_scene(_id: String) -> PackedScene:
		return scene

func _make_scene() -> PackedScene:
	var root := Node3D.new()
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps

func _map_with(decos: Array) -> MapData:
	var m := MapData.new()
	m.width = 5
	m.height = 5
	m.decorations = decos
	return m

func _deco(pos: Vector2i, facing := GridDirection.Dir.NORTH, scale := 1.0) -> Dictionary:
	return {"pos": pos, "model": "x", "facing": facing, "scale": scale}

func test_build_one_node_per_decoration():
	var layer := ObjectLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_deco(Vector2i(3, 3)), _deco(Vector2i(1, 1))]), cat)
	assert_eq(layer.get_child_count(), 2)

func test_build_positions_and_scales_node():
	var layer := ObjectLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_deco(Vector2i(2, 1), GridDirection.Dir.NORTH, 2.0)]), cat)
	var child: Node3D = layer.get_child(0)
	assert_eq(child.position, GridGeometry.cell_to_world(Vector2i(2, 1)))
	assert_eq(child.scale, Vector3.ONE * 2.0)

func test_build_clears_previous_children():
	var layer := ObjectLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_deco(Vector2i(0, 0))]), cat)
	layer.build(_map_with([_deco(Vector2i(1, 1))]), cat)
	assert_eq(layer.get_child_count(), 1)

func test_build_skips_unknown_model():
	var layer := ObjectLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = null
	layer.build(_map_with([_deco(Vector2i(0, 0))]), cat)
	assert_eq(layer.get_child_count(), 0)
