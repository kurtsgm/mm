class_name ChestLayer
extends Node3D

# 狀態感知寶箱渲染層：依 opened 集合（{Vector2i->true}）選 closed/open 場景。
# 切地圖時 build() 重建；開箱當下由 WorldStitchRenderer.refresh_objects 單區重建。
func build(map: MapData, opened: Dictionary, catalog = null) -> void:
	_clear()
	for obj in map.objects:
		var pos: Vector2i = obj["pos"]
		var is_open: bool = opened.has(pos)
		var scene: PackedScene = null
		if catalog != null:
			scene = catalog.get_scene(obj["model"], is_open)
		else:
			scene = ChestCatalog.get_scene(obj["model"], is_open)
		if scene == null:
			continue
		var inst := scene.instantiate()
		add_child(inst)
		if inst is Node3D:
			(inst as Node3D).position = GridGeometry.cell_to_world(pos)

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
