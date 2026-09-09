extends RefCounted
## Shared technical checks. Species-specific deformation/contact tests remain in GUT.

static func check_surface(arrays: Array, bind_count: int, slots: int = 4) -> Array[String]:
	var errors: Array[String] = []
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		errors.append("empty vertices")
	for vertex in vertices:
		if not vertex.is_finite():
			errors.append("non-finite vertex")
			break
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if (indices.size() if not indices.is_empty() else vertices.size()) % 3 != 0:
		errors.append("triangle index/vertex count is not divisible by 3")
	for index in indices:
		if index < 0 or index >= vertices.size():
			errors.append("index outside vertex array")
			break
	var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	if ids.size() != vertices.size() * slots or weights.size() != ids.size():
		errors.append("missing or malformed skin arrays")
		return errors
	for i in vertices.size():
		var total := 0.0
		for slot in slots:
			var offset := i * slots + slot
			if not is_finite(weights[offset]) or weights[offset] < 0 or ids[offset] < 0 or ids[offset] >= bind_count:
				errors.append("invalid weight or skin bind index at vertex %d" % i)
				return errors
			total += weights[offset]
		if absf(total - 1.0) > 0.0001:
			errors.append("unnormalized skin weights at vertex %d" % i)
			return errors
	return errors

static func budget_warnings(metrics: Dictionary, budgets: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	for key in ["triangles", "materials", "texture_edge", "bones", "glb_mib"]:
		if metrics.get(key, 0) > budgets[key]:
			warnings.append("%s: %s > draft budget %s" % [key, metrics[key], budgets[key]])
	return warnings

static func inspect(model: MonsterModel, spec: Dictionary, budgets: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var metrics := {"triangles": 0, "surfaces": 0, "materials": 0, "textures": 0, "texture_edge": 0, "bones": 0, "glb_mib": 0.0}
	var report := {"id": spec.id, "errors": errors, "warnings": [], "metrics": metrics}
	model.set_process(false)
	if model.skeleton == null or model.animation_player == null:
		errors.append("missing Skeleton3D or AnimationPlayer")
		return report
	var rig := model.skeleton
	metrics.bones = rig.get_bone_count()
	for name in spec.required_bones:
		if rig.find_bone(name) < 0:
			errors.append("missing bone: " + name)
	model.animation_player.stop()
	rig.reset_bone_poses()
	var materials := {}
	var textures := {}
	var bounds := AABB()
	var first := true
	for mesh in model._meshes:
		if mesh.mesh == null or mesh.skin == null:
			errors.append("missing mesh or skin: " + str(mesh.name))
			continue
		var box: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		var mesh_rig := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if mesh_rig != rig:
			errors.append("mesh points to a different or missing skeleton: " + str(mesh.name))
		for bind in mesh.skin.get_bind_count():
			var bone := rig.find_bone(mesh.skin.get_bind_name(bind))
			if bone < 0:
				bone = mesh.skin.get_bind_bone(bind)
			if bone < 0 or bone >= rig.get_bone_count():
				errors.append("invalid inverse bind bone: " + str(mesh.name))
				break
			var mesh_in_rig := rig.global_transform.affine_inverse() * mesh.global_transform
			if not (rig.get_bone_global_rest(bone) * mesh.skin.get_bind_pose(bind)).is_equal_approx(mesh_in_rig):
				errors.append("inverse bind does not restore mesh space: " + str(mesh.name))
				break
		for surface in mesh.mesh.get_surface_count():
			metrics.surfaces += 1
			if mesh.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				errors.append("non-triangle surface: " + str(mesh.name))
				continue
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var slots := 8 if mesh.mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4
			for error in check_surface(arrays, mesh.skin.get_bind_count(), slots):
				errors.append("%s[%d]: %s" % [mesh.name, surface, error])
			var indices = arrays[Mesh.ARRAY_INDEX]
			metrics.triangles += (indices.size() if indices != null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var material := mesh.get_active_material(surface)
			if material == null:
				errors.append("missing material: %s[%d]" % [mesh.name, surface])
				continue
			materials[material.get_instance_id()] = true
			for property in material.get_property_list():
				if property.type != TYPE_OBJECT:
					continue
				var texture = material.get(property.name)
				if texture is Texture2D:
					textures[texture.get_instance_id()] = true
					metrics.texture_edge = maxi(metrics.texture_edge, maxi(texture.get_width(), texture.get_height()))
	if first:
		errors.append("no skinned geometry")
	metrics.materials = materials.size()
	metrics.textures = textures.size()
	metrics.size = [bounds.size.x, bounds.size.y, bounds.size.z]
	metrics.rest_min_y = bounds.position.y
	for axis in 3:
		if bounds.size[axis] < spec.size_min[axis] or bounds.size[axis] > spec.size_max[axis]:
			errors.append("model size outside declared range on axis %d" % axis)
	if absf(bounds.position.y) > spec.ground_tolerance:
		errors.append("rest geometry origin is not at ground level")
	var glb := FileAccess.open(spec.glb, FileAccess.READ)
	if glb == null:
		errors.append("missing GLB: " + spec.glb)
	else:
		metrics.glb_mib = glb.get_length() / 1048576.0
	for path in spec.sources + [spec.provenance]:
		if not FileAccess.file_exists(path):
			errors.append("missing source/provenance: " + path)
	var definition = load(spec.definition) if ResourceLoader.exists(spec.definition) else null
	if not definition is MonsterDef or definition.id != spec.id:
		errors.append("missing or mismatched MonsterDef")
	if not MonsterModelCatalog.has_model(spec.id):
		errors.append("not registered in MonsterModelCatalog")
	elif MonsterModelCatalog._MODELS[spec.id].resource_path != spec.scene:
		errors.append("manifest scene differs from runtime catalog")
	var import_config := ConfigFile.new()
	if import_config.load(spec.glb + ".import") != OK:
		errors.append("missing GLB import settings")
	else:
		for setting in ["meshes/generate_lods", "animation/import"]:
			if not import_config.get_value("params", setting, false):
				errors.append("required import setting disabled: " + setting)
		if import_config.get_value("params", "import_script/path", "") != "res://tools/import_monster.gd":
			errors.append("GLB must use the shared monster importer")
		if import_config.get_value("params", "gltf/embedded_image_handling", -1) != 3:
			errors.append("GLB must preserve lossless embedded textures")
	_check_animations(model, spec, errors)
	report.warnings = budget_warnings(metrics, budgets)
	return report

static func _seek(model: MonsterModel, clip: String, time: float) -> void:
	model.animation_player.stop()
	model.skeleton.reset_bone_poses()
	model.animation_player.play(clip)
	model.animation_player.seek(time, true)
	model.animation_player.advance(0)

static func _check_animations(model: MonsterModel, spec: Dictionary, errors: Array[String]) -> void:
	var player := model.animation_player
	var rig := model.skeleton
	var anchor := model.transform
	for clip in ["idle", "walk", "attack", "hit", "RESET"]:
		if not player.has_animation(clip):
			errors.append("missing animation: " + clip)
			continue
		var animation := player.get_animation(clip)
		if animation.length <= 0 or not is_finite(animation.length):
			errors.append("invalid animation length: " + clip)
			continue
		if clip in ["attack", "hit"]:
			var duration := MonsterModel.ATTACK_DURATION if clip == "attack" else MonsterModel.HIT_DURATION
			if absf(animation.length - duration) > 0.002:
				errors.append("%s length differs from runtime driver (%s)" % [clip, duration])
		if clip in ["idle", "walk"] and animation.loop_mode != Animation.LOOP_LINEAR:
			errors.append("animation must loop: " + clip)
		if clip in ["attack", "hit"] and animation.loop_mode != Animation.LOOP_NONE:
			errors.append("one-shot animation must not loop: " + clip)
		# Disabling wrapping is essential: seeking a looping clip to length otherwise
		# returns frame zero and can conceal a broken last key.
		var loop_mode := animation.loop_mode
		animation.loop_mode = Animation.LOOP_NONE
		_seek(model, clip, 0)
		var start: Array[Transform3D] = []
		for bone in rig.get_bone_count():
			start.append(rig.get_bone_pose(bone))
		var moved_anchor := false
		var bad_hover := false
		var invalid_pose := false
		var moved_bones := false
		for sample in 11:
			_seek(model, clip, animation.length * sample / 10.0)
			moved_anchor = moved_anchor or not model.transform.is_equal_approx(anchor)
			for bone in rig.get_bone_count():
				invalid_pose = invalid_pose or not rig.get_bone_pose(bone).is_finite()
				moved_bones = moved_bones or not start[bone].is_equal_approx(rig.get_bone_pose(bone))
			if spec.locomotion == "hover" and clip != "RESET":
				for name in spec.get("hover_bones", []):
					var bone := rig.find_bone(name)
					bad_hover = bad_hover or bone < 0
					if bone >= 0:
						bad_hover = bad_hover or (rig.transform * rig.get_bone_global_pose(bone)).origin.y < spec.hover_min_y
		if moved_anchor:
			errors.append("animation moves world anchor: " + clip)
		if bad_hover:
			errors.append("hover bones fall below declared clearance: " + clip)
		if invalid_pose:
			errors.append("non-finite bone pose: " + clip)
		if not moved_bones and clip != "RESET":
			errors.append("animation has no bone motion: " + clip)
		if clip in ["idle", "walk"]:
			for bone in rig.get_bone_count():
				if not start[bone].is_equal_approx(rig.get_bone_pose(bone)):
					errors.append("loop endpoints differ: %s/%s" % [clip, rig.get_bone_name(bone)])
					break
		animation.loop_mode = loop_mode
		model.transform = anchor
	player.stop()
	rig.reset_bone_poses()
