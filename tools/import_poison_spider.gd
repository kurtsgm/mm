@tool
extends EditorScenePostImport

# The generated GLB contains COLOR_0. Enable it explicitly in Godot's materials
# so cuticle markings and joint collars survive a fresh scene import.
func _post_import(scene: Node) -> Object:
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material: BaseMaterial3D = mesh.mesh.surface_get_material(surface)
			if material != null:
				material.vertex_color_use_as_albedo = true
	return scene
