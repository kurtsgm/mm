@tool
extends EditorScenePostImport

# Preserve painted wing eyespots and complexion colors in the imported asset.
func _post_import(scene: Node) -> Object:
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material: BaseMaterial3D = mesh.mesh.surface_get_material(surface)
			if material != null:
				material.vertex_color_use_as_albedo = true
	return scene
