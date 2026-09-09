@tool
extends EditorScenePostImport
## Shared import contract: preserve COLOR_0 and restore loop flags lost in glTF.

func _post_import(scene: Node) -> Object:
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null:
				material.vertex_color_use_as_albedo = true
	for player in scene.find_children("*", "AnimationPlayer", true, false):
		for clip in ["idle", "walk", "attack", "hit", "RESET"]:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in ["idle", "walk"] else Animation.LOOP_NONE
	return scene
