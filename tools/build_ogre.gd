extends SceneTree
## Bake the editable ogre geometry into the shared MonsterModel contract.
const SOURCE := "res://art_source/ogre/production/"
const OUT := "res://content/monsters/models/ogre.glb"
var model := Node3D.new()
var rig := Skeleton3D.new()
var bones: Dictionary = {}
var rests: Dictionary = {}
var surfaces: Dictionary = {}
var materials: Dictionary = {}
var manifest: Dictionary

func _initialize() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "geometry_manifest.json"))
	model.name = "Ogre"
	rig.name = "Skeleton3D"
	model.add_child(rig)
	rig.owner = model
	for label in manifest.bones:
		var spec: Dictionary = manifest.bones[label]
		var p: Array = spec.position
		_bone(label, spec.parent, Vector3(p[0], p[1], p[2]))
	var document := GLTFDocument.new()
	var input := GLTFState.new()
	var result := document.append_from_file(SOURCE + "ogre_geometry.glb", input)
	if result != OK:
		push_error("Cannot read ogre geometry: " + error_string(result))
		quit(1)
		return
	var source := document.generate_scene(input)
	_collect(source)
	_finish()
	_animations()
	var state := GLTFState.new()
	result = document.append_from_scene(model, state)
	if result == OK:
		result = document.write_to_filesystem(state, OUT)
	print("Ogre: %d bones, %d material surfaces. %s" % [rig.get_bone_count(), surfaces.size(), error_string(result)])
	source.free()
	model.free()
	quit(0 if result == OK else 1)

func _bone(label: String, parent: String, position: Vector3) -> void:
	var index := rig.get_bone_count()
	bones[label] = index
	rests[label] = position
	rig.add_bone(label)
	if not parent.is_empty():
		rig.set_bone_parent(index, bones[parent])
	var local: Vector3 = position - rests.get(parent, Vector3.ZERO)
	rig.set_bone_rest(index, Transform3D(Basis.IDENTITY, local))
	rig.set_bone_pose_position(index, local)

func _pair(a: String, b: String, weight: float) -> Dictionary:
	return {a: 1.0 - weight, b: weight}

func _weights(p: Vector3, tag: String, arm_mask: float = -1.0) -> Dictionary:
	var side := "L" if p.x >= 0 else "R"
	if tag.begins_with("skirt_"):
		return _pair("pelvis", tag, smoothstep(1.44, 0.96, p.y) * 0.65)
	if bones.has(tag):
		return {tag: 1.0}
	if p.y > 2.71:
		return {"head": 1.0}
	if p.y > 2.57 and absf(p.x) < 0.43:
		return _pair("neck", "head", smoothstep(2.57, 2.71, p.y))
	var core: Dictionary
	if p.y < 0.30:
		core = _pair("shin_" + side, "foot_" + side, smoothstep(0.31, 0.15, p.y))
	elif p.y < 0.84:
		core = _pair("thigh_" + side, "shin_" + side, smoothstep(0.82, 0.53, p.y))
	elif p.y < 1.35:
		core = _pair("thigh_" + side, "pelvis", smoothstep(1.04, 1.35, p.y))
	elif p.y < 1.91:
		core = _pair("pelvis", "spine", smoothstep(1.43, 1.88, p.y))
	else:
		core = _pair("spine", "chest", smoothstep(1.96, 2.40, p.y))
	var limit := lerpf(0.88, 0.48, smoothstep(1.55, 2.43, p.y))
	var mix := smoothstep(limit, limit + 0.12, absf(p.x)) if p.y > 0.85 else 0.0
	if arm_mask >= 0:
		mix = arm_mask
	if mix > 0:
		var arm: Dictionary
		if p.y > 1.73:
			arm = _pair("upper_arm_" + side, "forearm_" + side, smoothstep(2.02, 1.73, p.y))
		else:
			arm = _pair("forearm_" + side, "hand_" + side, smoothstep(1.53, 1.30, p.y))
		for name in core:
			core[name] *= 1.0 - mix
		for name in arm:
			core[name] = core.get(name, 0.0) + arm[name] * mix
	return core

# Weld UV seams, classify the disconnected arms below the armpits, then
# diffuse across the shoulder surface. A spatial X threshold cuts thick arms.
func _component(parents: Array[int], i: int) -> int:
	while parents[i] != i:
		parents[i] = parents[parents[i]]
		i = parents[i]
	return i

func _arm_mask(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedFloat32Array:
	var welded := {}
	var ids: Array[int] = []
	var points: Array[Vector3] = []
	var parents: Array[int] = []
	var neighbors: Array[Dictionary] = []
	for p in vertices:
		var key := Vector3i((p * 100000).round())
		if not welded.has(key):
			welded[key] = points.size()
			parents.append(points.size())
			points.append(p)
			neighbors.append({})
		ids.append(welded[key])
	for t in range(0, indices.size(), 3):
		for slot in 3:
			var a := ids[indices[t + slot]]
			var b := ids[indices[t + (slot + 1) % 3]]
			var influence := 1.0 / maxf(points[a].distance_to(points[b]), 0.00001)
			neighbors[a][b] = influence
			neighbors[b][a] = influence
			if points[a].y < 2.15 and points[b].y < 2.15:
				parents[_component(parents, a)] = _component(parents, b)
	var arms := {}
	for i in points.size():
		if points[i].y < 2.15 and absf(points[i].x) > 1.1:
			arms[_component(parents, i)] = true
	var mask := PackedFloat32Array()
	var fixed: Array[bool] = []
	for i in points.size():
		fixed.append(points[i].y < 1.98 or absf(points[i].x) < 0.28 or points[i].y > 2.62)
		mask.append(float(arms.has(_component(parents, i))) if points[i].y < 2.15 else smoothstep(0.35, 0.95, absf(points[i].x)))
	for iteration in 240:
		var next := mask.duplicate()
		for i in points.size():
			if fixed[i] or neighbors[i].is_empty():
				continue
			var total := 0.0
			var sum := 0.0
			for neighbor in neighbors[i]:
				total += mask[neighbor] * neighbors[i][neighbor]
				sum += neighbors[i][neighbor]
			next[i] = total / sum
		mask = next
	var result := PackedFloat32Array()
	for i in ids:
		result.append(mask[i])
	return result

func _collect(node: Node, transform: Transform3D = Transform3D.IDENTITY) -> void:
	if node is Node3D:
		transform *= node.transform
	if node is MeshInstance3D:
		var info: Dictionary = manifest.parts[str(node.name)]
		for surface in node.mesh.get_surface_count():
			var material: StandardMaterial3D = node.mesh.surface_get_material(surface)
			var label := material.resource_name
			if not surfaces.has(label):
				material.vertex_color_use_as_albedo = true
				material.albedo_color = Color.WHITE
				materials[label] = material
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				surfaces[label] = st
			var st: SurfaceTool = surfaces[label]
			var a: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var colors: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vertices.size():
					indices.append(i)
			var arm_mask := _arm_mask(vertices, indices) if info.source == "Skin" else PackedFloat32Array()
			for triangle in range(0, indices.size(), 3):
				var ia := indices[triangle]
				var ib := indices[triangle + 1]
				var ic := indices[triangle + 2]
				if (vertices[ib] - vertices[ia]).cross(vertices[ic] - vertices[ia]).dot(normals[ia] + normals[ib] + normals[ic]) > 0:
					indices[triangle + 1] = ic
					indices[triangle + 2] = ib
			for index in indices:
				var p: Vector3 = transform * vertices[index]
				var weights := _weights(p, info.attachment, arm_mask[index] if not arm_mask.is_empty() else -1.0)
				st.set_normal((transform.basis.inverse().transposed() * normals[index]).normalized())
				st.set_uv(uv[index] if not uv.is_empty() else Vector2.ZERO)
				st.set_color(colors[index].linear_to_srgb() if not colors.is_empty() else Color.WHITE)
				var ids := PackedInt32Array([0, 0, 0, 0])
				var values := PackedFloat32Array([0, 0, 0, 0])
				var slot := 0
				for name in weights:
					if weights[name] <= 0:
						continue
					ids[slot] = bones[name]
					values[slot] = weights[name]
					slot += 1
				st.set_bones(ids)
				st.set_weights(values)
				st.add_vertex(p)
	for child in node.get_children():
		_collect(child, transform)

func _finish() -> void:
	var skin := rig.create_skin_from_rest_transforms()
	var triangles := 0
	for label in surfaces:
		var st: SurfaceTool = surfaces[label]
		st.index()
		st.generate_tangents()
		var mesh := MeshInstance3D.new()
		mesh.name = label
		mesh.mesh = st.commit()
		mesh.mesh.surface_set_material(0, materials[label])
		mesh.skin = skin
		mesh.skeleton = NodePath("..")
		mesh.extra_cull_margin = 1.3
		rig.add_child(mesh)
		mesh.owner = model
		triangles += mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	print("Ogre base triangles: ", triangles)

func _animations() -> void:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	player.owner = model
	var library := AnimationLibrary.new()
	for clip in ["RESET", "idle", "walk", "attack", "hit"]:
		var animation := Animation.new()
		animation.length = {"RESET": 0.0, "idle": 2.6, "walk": 0.72, "attack": 0.58, "hit": 0.32}[clip]
		if clip in ["idle", "walk"]:
			animation.loop_mode = Animation.LOOP_LINEAR
		var frames := maxi(1, ceili(animation.length * 60))
		var tracks := {}
		for label in bones:
			var pt := animation.add_track(Animation.TYPE_POSITION_3D)
			var rt := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(pt, NodePath("Skeleton3D:" + label))
			animation.track_set_path(rt, NodePath("Skeleton3D:" + label))
			tracks[label] = [pt, rt]
		for frame in range(frames + 1):
			var t := float(frame) / frames
			var poses := _poses(clip, t)
			for label in bones:
				animation.position_track_insert_key(tracks[label][0], t * animation.length, poses[label][0])
				animation.rotation_track_insert_key(tracks[label][1], t * animation.length, poses[label][1])
		library.add_animation(clip, animation)
	player.add_animation_library("", library)

func _leg_ik(poses: Dictionary, side: String, target: Vector3, hip_offset: Vector3) -> void:
	var hip: Vector3 = rests["thigh_" + side] + hip_offset
	var upper: Vector3 = rests["shin_" + side] - rests["thigh_" + side]
	var lower: Vector3 = rests["foot_" + side] - rests["shin_" + side]
	var direction := (target - hip).normalized()
	var length := clampf(hip.distance_to(target), 0.01, upper.length() + lower.length() - 0.0001)
	var cosine := clampf((upper.length_squared() + length * length - lower.length_squared()) / (2 * upper.length() * length), -1, 1)
	var bend := (Vector3.BACK - direction * Vector3.BACK.dot(direction)).normalized()
	var knee := hip + (direction * cosine + bend * sqrt(1 - cosine * cosine)) * upper.length()
	var thigh_rotation := Quaternion(upper.normalized(), (knee - hip).normalized())
	var shin_rotation := Quaternion(lower.normalized(), (target - knee).normalized())
	poses["thigh_" + side][1] = thigh_rotation
	poses["shin_" + side][1] = thigh_rotation.inverse() * shin_rotation
	poses["foot_" + side][1] = shin_rotation.inverse()

func _poses(clip: String, t: float) -> Dictionary:
	var poses := {}
	for label in bones:
		poses[label] = [rig.get_bone_rest(bones[label]).origin, Quaternion.IDENTITY]
	if clip == "RESET":
		return poses
	var wave := sin(t * TAU)
	var pulse := sin(t * PI)
	poses.spine[1] = Quaternion(Vector3.RIGHT, -0.015 + wave * 0.009)
	poses.chest[1] = Quaternion(Vector3.RIGHT, wave * 0.010)
	poses.head[1] = Quaternion(Vector3.UP, wave * 0.024)
	for side in ["R", "L"]:
		var sign := 1.0 if side == "R" else -1.0
		poses["forearm_" + side][1] = Quaternion(Vector3.RIGHT, -0.025 + wave * 0.012)
		if clip == "walk":
			var phase := t * TAU + (0.0 if side == "R" else PI)
			var hip_offset := Vector3(0, -0.07 + 0.008 * cos(phase * 2), 0)
			poses.pelvis[0] += hip_offset * 0.5
			var target: Vector3 = rests["foot_" + side] + Vector3(0, maxf(0, sin(phase)) * 0.09, cos(phase) * 0.16)
			_leg_ik(poses, side, target, hip_offset)
			poses["upper_arm_" + side][1] = Quaternion(Vector3.RIGHT, -sin(phase) * 0.11)
			poses["skirt_" + side][1] = Quaternion(Vector3.RIGHT, sin(phase) * 0.12)
			poses.chest[1] = Quaternion(Vector3.UP, wave * 0.035)
		if clip == "attack":
			var wind := smoothstep(0.0, 0.34, t)
			var strike := smoothstep(0.34, 0.64, t)
			var recover := 1.0 - smoothstep(0.68, 1.0, t)
			poses.upper_arm_R[1] = Quaternion.from_euler(Vector3((-1.8 * wind + 2.05 * strike) * recover, 0, 0.08 * wind * recover))
			poses.forearm_R[1] = Quaternion(Vector3.RIGHT, -0.72 * wind * (1.0 - strike) * recover)
			poses.hand_R[1] = Quaternion(Vector3.RIGHT, 0.20 * wind * (1.0 - strike) * recover)
			poses.upper_arm_L[1] = Quaternion(Vector3.RIGHT, -0.23 * pulse)
			poses.spine[1] = Quaternion(Vector3.UP, (0.20 * wind - 0.35 * strike) * recover)
			poses.chest[1] = Quaternion(Vector3.RIGHT, (0.08 * strike - 0.06 * wind) * recover)
			poses.jaw[1] = Quaternion(Vector3.RIGHT, 0.025 * pulse)
		if clip == "hit":
			poses.chest[1] = Quaternion(Vector3.RIGHT, -0.17 * pulse)
			poses.head[1] = Quaternion(Vector3.RIGHT, -0.13 * pulse)
			poses["upper_arm_" + side][1] = Quaternion(Vector3.BACK, sign * 0.08 * pulse)
	return poses
