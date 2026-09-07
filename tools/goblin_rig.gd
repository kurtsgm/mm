extends RefCounted

# Offline rig/skin/animation baker. No authoring geometry is built at runtime.
var root: Node3D
var skeleton: Skeleton3D
var bones: Dictionary = {}
var positions: Dictionary = {}
var scale_factor: float

func bone(label: String, parent: String, position: Vector3) -> void:
	var index := skeleton.get_bone_count()
	bones[label] = index
	positions[label] = position * scale_factor
	skeleton.add_bone(label)
	if not parent.is_empty():
		skeleton.set_bone_parent(index, bones[parent])
	var origin: Vector3 = positions[label] - positions.get(parent, Vector3.ZERO)
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, origin))
	skeleton.set_bone_pose_position(index, origin)

func build(model: Node3D, factor: float) -> void:
	root = model
	scale_factor = factor
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	root.add_child(skeleton)
	skeleton.owner = root
	bone("root", "", Vector3.ZERO)
	bone("pelvis", "root", Vector3(0,0.88,0))
	bone("spine", "pelvis", Vector3(0,1.09,0))
	bone("chest", "spine", Vector3(0,1.33,-0.015))
	bone("neck", "chest", Vector3(0,1.49,0.02))
	bone("head", "neck", Vector3(0,1.61,0.055))
	bone("jaw", "head", Vector3(0,1.59,0.15))
	for side in [-1.0,1.0]:
		var suffix := "_R" if side < 0 else "_L"
		bone("ear"+suffix,"head",Vector3(side*0.17,1.74,0.03))
		bone("clavicle"+suffix,"chest",Vector3(side*0.12,1.39,-0.005))
		bone("upper_arm"+suffix,"clavicle"+suffix,Vector3(side*0.32,1.37,-0.005))
		bone("forearm"+suffix,"upper_arm"+suffix,Vector3(side*0.47,1.08,0.03))
		bone("hand"+suffix,"forearm"+suffix,Vector3(side*0.485,0.79,0.15))
		for i in 5:
			var finger := "finger_%d" % i + suffix
			var p := Vector3(side*0.485-0.047+i*0.03,0.80,0.194)
			if i == 4:
				p = Vector3(side*0.417,0.806,0.175)
			bone(finger,"hand"+suffix,p)
			bone(finger+"_tip",finger,p+Vector3(0,-0.045,0.012))
		bone("thigh"+suffix,"pelvis",Vector3(side*0.15,0.85,0))
		bone("shin"+suffix,"thigh"+suffix,Vector3(side*0.21,0.50,0.07))
		bone("foot"+suffix,"shin"+suffix,Vector3(side*0.255,0.14,0.01))
		bone("toe"+suffix,"foot"+suffix,Vector3(side*0.255,0.05,0.15))
	var groups: Dictionary = {}
	for child in root.get_children():
		if child != skeleton:
			_collect(child, Transform3D.IDENTITY, "", groups)
	for child in root.get_children():
		if child != skeleton:
			child.free()
	var skin := skeleton.create_skin_from_rest_transforms()
	for mat in groups:
		var st: SurfaceTool = groups[mat]
		st.index()
		st.generate_tangents()
		var mesh := MeshInstance3D.new()
		mesh.name = mat.resource_name.replace(" ", "")
		mesh.mesh = st.commit()
		mesh.mesh.surface_set_material(0, mat)
		mesh.skin = skin
		mesh.skeleton = NodePath("..")
		mesh.extra_cull_margin = 1.0
		skeleton.add_child(mesh)
		mesh.owner = root
	_animations()
	root.set_meta("asset_version", 2)
	root.set_meta("rig_bones", skeleton.get_bone_count())
	print("Skinned goblin: ", skeleton.get_bone_count(), " bones, ", groups.size(), " material surfaces")

func _collect(node: Node3D, parent_transform: Transform3D, path: String, groups: Dictionary) -> void:
	var transform := parent_transform * node.transform
	path += "/" + str(node.name)
	if node is MeshInstance3D:
		var mat: Material = node.material_override
		if not groups.has(mat):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[mat] = surface
		var st: SurfaceTool = groups[mat]
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in vertices.size():
				indices.append(i)
		for i in indices:
			var p: Vector3 = transform * vertices[i]
			var weights := _weights(path, p / scale_factor, mat.resource_name)
			st.set_bones(PackedInt32Array([bones[weights[0]],bones[weights[1]],0,0]))
			st.set_weights(PackedFloat32Array([1.0-weights[2],weights[2],0,0]))
			st.set_normal((transform.basis.inverse().transposed()*normals[i]).normalized())
			var uv := Vector2(p.x,p.y)
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				uv = arrays[Mesh.ARRAY_TEX_UV][i]
			st.set_uv(uv)
			st.set_color(arrays[Mesh.ARRAY_COLOR][i] if arrays[Mesh.ARRAY_COLOR] != null else Color.WHITE)
			st.add_vertex(p)
	for child in node.get_children():
		_collect(child, transform, path, groups)

func _weights(path: String, p: Vector3, material: String) -> Array:
	var suffix := "_R" if "Right" in path else "_L"
	if "/Head" in path:
		if absf(p.x) > 0.19:
			return ["head","ear"+("_R" if p.x<0 else "_L"),smoothstep(0.18,0.33,absf(p.x))]
		if p.y < 1.59 and p.z > 0.16:
			return ["head","jaw",smoothstep(1.60,1.55,p.y)]
		return ["neck","head",smoothstep(1.53,1.66,p.y)]
	if "Arm" in path:
		if "/Cleaver" in path or "/Buckler" in path:
			return ["hand"+suffix,"hand"+suffix,0.0]
		if "/Hand" in path:
			var hand_x := -0.485 if suffix == "_R" else 0.485
			var toward_thumb: float = (p.x-hand_x) * (1.0 if suffix == "_R" else -1.0)
			if toward_thumb > 0.056:
				return ["finger_4"+suffix,"finger_4"+suffix+"_tip",smoothstep(0.81,0.77,p.y)]
			if p.z > 0.185 and p.y < 0.807:
				var finger := "finger_%d" % clampi(roundi((p.x-hand_x+0.047)/0.03),0,3)+suffix
				return [finger,finger+"_tip",smoothstep(0.79,0.75,p.y)]
			return ["forearm"+suffix,"hand"+suffix,smoothstep(0.88,0.80,p.y)]
		if material in ["Blackened iron","Honed steel","Old brass"]:
			return ["upper_arm"+suffix,"upper_arm"+suffix,0.0]
		if p.y > 1.25:
			return ["chest","upper_arm"+suffix,smoothstep(0.22,0.38,absf(p.x))]
		if p.y > 0.89:
			return ["upper_arm"+suffix,"forearm"+suffix,smoothstep(1.17,0.99,p.y)]
		return ["forearm"+suffix,"hand"+suffix,smoothstep(0.89,0.78,p.y)]
	if "Leg" in path:
		if p.y > 0.24:
			return ["thigh"+suffix,"shin"+suffix,smoothstep(0.61,0.41,p.y)]
		if p.y < 0.07 and p.z > 0.1:
			return ["foot"+suffix,"toe"+suffix,smoothstep(0.1,0.2,p.z)]
		return ["shin"+suffix,"foot"+suffix,smoothstep(0.23,0.12,p.y)]
	if p.y > 1.21:
		return ["spine","chest",smoothstep(1.21,1.37,p.y)]
	return ["pelvis","spine",smoothstep(0.96,1.20,p.y)]

func _animations() -> void:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var library := AnimationLibrary.new()
	for clip in ["RESET","idle","walk","attack","hit"]:
		var animation := Animation.new()
		animation.length = {"RESET":0.0,"idle":2.6,"walk":0.72,"attack":0.58,"hit":0.32}[clip]
		if clip in ["idle","walk"]:
			animation.loop_mode = Animation.LOOP_LINEAR
		var frames := maxi(1,ceili(animation.length*30))
		for label in bones:
			var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(rotation_track, NodePath("Skeleton3D:"+label))
			var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(position_track, NodePath("Skeleton3D:"+label))
			var rest: Vector3 = skeleton.get_bone_rest(bones[label]).origin
			for frame in range(frames+1):
				var t := float(frame)/frames
				var pose := _pose(clip,label,t)
				animation.rotation_track_insert_key(rotation_track,t*animation.length,Quaternion.from_euler(pose[0]))
				animation.position_track_insert_key(position_track,t*animation.length,rest+pose[1]*scale_factor)
		library.add_animation(clip, animation)
	player.add_animation_library("",library)

func _pose(clip: String, label: String, t: float) -> Array:
	var r := Vector3.ZERO
	var p := Vector3.ZERO
	var breath := sin(t*TAU)
	var side := 1.0 if label.ends_with("_R") else -1.0
	if clip == "idle":
		if label == "spine": r.x = -0.025+breath*0.012
		if label == "chest": r.x = breath*0.016
		if label == "head": r.y = breath*0.035
		if label.begins_with("upper_arm"): r.z = -side*(0.065+breath*0.012)
		if label.begins_with("forearm"): r.x = -0.10
		if label.begins_with("ear"): r.z = side*breath*0.025
	elif clip == "walk":
		var step := sin(t*TAU)*side
		if label == "pelvis": p.y = absf(breath)*0.025
		if label == "spine": r.y = breath*0.06
		if label.begins_with("thigh"): r.x = step*0.34
		if label.begins_with("shin"): r.x = -maxf(0.0,step)*0.48
		if label.begins_with("foot"): r.x = maxf(0.0,step)*0.18
		if label.begins_with("upper_arm"): r.x = -step*0.22
		if label.begins_with("forearm"): r.x = -0.16
	elif clip == "attack":
		var wind := sin(clampf(t/0.32,0,1)*PI/2)
		var cut := smoothstep(0.30,0.60,t)
		var recover := 1.0-smoothstep(0.66,1.0,t)
		if label == "upper_arm_R": r = Vector3(-1.7*wind+2.7*cut,0,0.4*wind-0.95*cut)*recover
		if label == "forearm_R": r.x = -0.55*wind*(1.0-cut)*recover
		if label == "hand_R": r = Vector3(1.9*wind*(1.0-cut),0,-cut*0.15)*recover
		if label == "spine": r = Vector3(cut*0.10,0.30*wind-0.58*cut,0)*recover
		if label == "chest": r.y = (wind*0.14-cut*0.22)*recover
		if label == "upper_arm_L": r.x = -sin(t*PI)*0.38
		if label == "jaw": r.x = sin(t*PI)*0.09
	elif clip == "hit":
		var recoil := sin(t*PI)
		if label == "spine": r = Vector3(-recoil*0.20,0,sin(t*TAU*2)*(1-t)*0.055)
		if label == "head": r.x = -recoil*0.14
		if label == "jaw": r.x = recoil*0.11
	return [r,p]

static func texture_materials(materials: Dictionary) -> void:
	# Tileable, baked microdetail maps with fixed seed; shared by material families.
	var directory := "res://content/monsters/models/textures/"
	DirAccess.make_dir_recursive_absolute(directory)
	for family in ["skin","leather","iron","cloth"]:
		var noise := FastNoiseLite.new()
		noise.seed = {"skin":71,"leather":113,"iron":229,"cloth":337}[family]
		noise.frequency = 0.18
		var image := Image.create(256,256,false,Image.FORMAT_RGB8)
		var normal := Image.create(256,256,false,Image.FORMAT_RGB8)
		var rough := Image.create(256,256,false,Image.FORMAT_RGB8)
		for y in 256:
			for x in 256:
				var n := _tile_noise(noise,x,y)
				var value := 0.88+n*0.16
				if family == "cloth": value -= 0.06*(sin(x*PI/2)*sin(y*PI/2))
				image.set_pixel(x,y,Color(value,value,value))
				var dx := _tile_noise(noise,x+1,y)-_tile_noise(noise,x-1,y)
				var dy := _tile_noise(noise,x,y+1)-_tile_noise(noise,x,y-1)
				var v := Vector3(-dx*0.65,-dy*0.65,1).normalized()
				normal.set_pixel(x,y,Color(v.x*0.5+0.5,v.y*0.5+0.5,v.z*0.5+0.5))
				var rv := clampf(0.83+n*0.18,0,1)
				rough.set_pixel(x,y,Color(rv,rv,rv))
		image.generate_mipmaps()
		normal.generate_mipmaps()
		rough.generate_mipmaps()
		image.save_png(directory+family+"_color.png")
		normal.save_png(directory+family+"_normal.png")
		rough.save_png(directory+family+"_roughness.png")
		var color_tex := ImageTexture.create_from_image(image)
		var normal_tex := ImageTexture.create_from_image(normal)
		var rough_tex := ImageTexture.create_from_image(rough)
		for key in materials:
			var target: String = "skin" if key in ["skin","skin_dark","ear"] else ("leather" if key in ["leather","edge"] else ("iron" if key in ["iron","steel","brass"] else key))
			if target != family: continue
			var mat: StandardMaterial3D = materials[key]
			mat.albedo_texture = color_tex
			mat.normal_enabled = true
			mat.normal_texture = normal_tex
			mat.normal_scale = 0.5 if family == "skin" else 0.7
			mat.roughness_texture = rough_tex
			mat.uv1_scale = Vector3(3,3,3)

static func _tile_noise(noise: FastNoiseLite, x: int, y: int) -> float:
	var u := float(posmod(x,256))/256.0
	var v := float(posmod(y,256))/256.0
	return lerpf(lerpf(noise.get_noise_2d(u*256,v*256),noise.get_noise_2d((u-1)*256,v*256),u),lerpf(noise.get_noise_2d(u*256,(v-1)*256),noise.get_noise_2d((u-1)*256,(v-1)*256),u),v)
