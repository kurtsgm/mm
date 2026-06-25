class_name ObjectLayer
extends Node3D

# 把 map.decorations 生成可見模型擺到格子世界座標。切地圖時 build() 會重建。
func build(map: MapData, catalog = null) -> void:
	_clear()
	for deco in map.decorations:
		var scene: PackedScene = null
		if catalog != null:
			scene = catalog.get_scene(deco["model"])
		else:
			scene = DecorationCatalog.get_scene(deco["model"])
		if scene == null:
			continue
		var inst := scene.instantiate()
		add_child(inst)
		if inst is Node3D:
			var n: Node3D = inst
			n.position = GridGeometry.cell_to_world(deco["pos"])
			n.rotation.y = GridGeometry.facing_to_yaw(deco["facing"])
			n.scale = Vector3.ONE * float(deco["scale"])

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
