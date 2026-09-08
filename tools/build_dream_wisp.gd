extends SceneTree

# Offline skinning and animation bake of the editable Blender fairy source.
const OUT := "res://content/monsters/models/dream_wisp.glb"
const SOURCE := "res://art_source/dream_wisp/production/"
const SCALE := 0.494
var model := Node3D.new()
var rig := Skeleton3D.new()
var bones: Dictionary = {}
var rests: Dictionary = {}
var surfaces: Dictionary = {}
var materials: Dictionary = {}
var manifest: Dictionary

func _bone(label: String, parent: String, p: Vector3) -> void:
	var id := rig.get_bone_count()
	bones[label] = id
	rests[label] = p
	rig.add_bone(label)
	if not parent.is_empty():
		rig.set_bone_parent(id, bones[parent])
	var local: Vector3 = p - rests.get(parent, Vector3.ZERO)
	rig.set_bone_rest(id, Transform3D(Basis.IDENTITY, local))
	rig.set_bone_pose_position(id, local)

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
		mesh.mesh.surface_set_material(0,materials[label])
		mesh.skin = skin
		mesh.skeleton = NodePath("..")
		mesh.extra_cull_margin = 0.4
		rig.add_child(mesh)
		mesh.owner = model
		triangles += mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
	print("Base mesh triangles: ",triangles)

# Bake hovering, wing beats and casting into standard glTF animation tracks.
func _animations() -> void:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	player.owner = model
	var library := AnimationLibrary.new()
	for clip in ["RESET","idle","walk","attack","hit"]:
		var animation := Animation.new()
		animation.length = {"RESET":0.0,"idle":2.6,"walk":0.72,"attack":0.58,"hit":0.32}[clip]
		if clip in ["idle","walk"]: animation.loop_mode = Animation.LOOP_LINEAR
		var frames := maxi(1,ceili(animation.length*60))
		var tracks: Dictionary = {}
		for label in bones:
			var pt := animation.add_track(Animation.TYPE_POSITION_3D)
			var rt := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(pt,NodePath("Skeleton3D:"+label))
			animation.track_set_path(rt,NodePath("Skeleton3D:"+label))
			tracks[label] = [pt,rt]
		for frame in range(frames+1):
			var t := float(frame)/frames
			var poses := _poses(clip,t)
			for label in bones:
				animation.position_track_insert_key(tracks[label][0],t*animation.length,poses[label][0])
				animation.rotation_track_insert_key(tracks[label][1],t*animation.length,poses[label][1])
		library.add_animation(clip,animation)
	player.add_animation_library("",library)

func _p(x: float, y: float, z: float) -> Vector3:
	return Vector3(x,z,-y)*SCALE

func _rig() -> void:
	_bone("root","",Vector3.ZERO)
	_bone("pelvis","root",_p(0,0.020,0.91))
	_bone("spine","pelvis",_p(0,-0.018,1.08))
	_bone("chest","spine",_p(0,-0.02,1.26))
	_bone("neck","chest",_p(0,-0.018,1.395))
	_bone("head","neck",_p(0,-0.044,1.45))
	for side in [-1.0,1.0]:
		var s := "L" if side>0 else "R"
		_bone("ear_"+s,"head",_p(side*0.080,-0.018,1.535))
		_bone("upper_arm_"+s,"chest",_p(side*0.163,-0.010,1.325))
		_bone("forearm_"+s,"upper_arm_"+s,_p(side*0.254,-0.034,1.095))
		_bone("hand_"+s,"forearm_"+s,_p(side*0.349,-0.011,0.898))
		for finger in 5:
			_bone("finger_%d_"%finger+s,"hand_"+s,_p(side*(0.373+finger*0.006),-0.009,0.860))
		_bone("thigh_"+s,"pelvis",_p(side*0.090,0.017,0.880))
		_bone("shin_"+s,"thigh_"+s,_p(side*0.118,0.005,0.465))
		_bone("foot_"+s,"shin_"+s,_p(side*0.128,0.045,0.085))
		_bone("wing_upper_"+s,"chest",_p(side*0.053,0.065,1.27))
		_bone("wing_lower_"+s,"chest",_p(side*0.053,0.065,1.20))
		_bone("skirt_"+s,"pelvis",_p(side*0.09,-0.02,1.035))
		_bone("hair_"+s,"head",_p(side*0.045,0.0,1.51))
	_bone("spell","hand_L",_p(0.39,-0.10,0.92))

# Blend only anatomically adjacent joints. Garment and wing tags override body regions.
func _pair(a: String, b: String, t: float) -> Dictionary:
	if a==b: return {a:1.0}
	return {a:1.0-t,b:t}

func _weights(p: Vector3, source: String, tag: String, mat: String) -> Dictionary:
	var q := p/SCALE
	var side := "L" if q.x>=0 else "R"
	if tag.begins_with("wing_") or tag=="spell": return {tag:1.0}
	if tag.begins_with("skirt_") or source=="Skirt_lining":
		return _pair("pelvis","skirt_"+side,smoothstep(1.025,0.72,q.y)*0.80)
	if mat in ["Hair","Brows","EyeWhite","Iris","Pupil"] or source.begins_with("Circlet") or source.begins_with("Moonstone"):
		if mat=="Hair": return _pair("head","hair_"+side,smoothstep(1.50,1.28,q.y)*0.75)
		return {"head":1.0}
	if q.y>1.44: return {"head":1.0}
	if q.y>1.395: return _pair("neck","head",smoothstep(1.395,1.44,q.y))
	var core: Dictionary
	if q.y<0.21: core=_pair("shin_"+side,"foot_"+side,smoothstep(0.19,0.095,q.y))
	elif q.y<0.57: core=_pair("thigh_"+side,"shin_"+side,smoothstep(0.53,0.40,q.y))
	elif q.y<0.94: core=_pair("thigh_"+side,"pelvis",smoothstep(0.79,0.94,q.y))
	elif q.y<1.10: core=_pair("pelvis","spine",smoothstep(0.97,1.10,q.y))
	else: core=_pair("spine","chest",smoothstep(1.10,1.24,q.y))
	# A continuous lateral blend around the shoulder and armpit joins the two
	# chains without hard height cutoffs; all fingers remain in the hand region.
	var limit := lerpf(0.145,0.175,clampf((1.25-q.y)/0.31,0,1))
	if q.y<0.94: limit=lerpf(0.175,0.24,smoothstep(0.94,0.84,q.y))
	var arm_mix := smoothstep(limit-0.02,limit+0.035,absf(q.x)) if q.y>0.50 else 0.0
	if source.begins_with("Bodice") or source.begins_with("Belt") or source.begins_with("Clasp"): arm_mix=0.0
	if arm_mix>0:
		var arm: Dictionary
		if q.y>1.04: arm=_pair("upper_arm_"+side,"forearm_"+side,smoothstep(1.15,1.04,q.y))
		else: arm=_pair("forearm_"+side,"hand_"+side,smoothstep(0.97,0.875,q.y))
		for name in core: core[name]*=1.0-arm_mix
		for name in arm: core[name]=core.get(name,0.0)+arm[name]*arm_mix
	return core

func _collect(node: Node, transform: Transform3D = Transform3D.IDENTITY) -> void:
	if node is Node3D: transform=transform*node.transform
	if node is MeshInstance3D:
		var info: Dictionary=manifest.get(str(node.name),{})
		for surface in node.mesh.get_surface_count():
			var material: StandardMaterial3D=node.mesh.surface_get_material(surface)
			var label:=material.resource_name
			if not surfaces.has(label):
				material.vertex_color_use_as_albedo=true
				if label=="Skin": material.albedo_color=Color.WHITE
				materials[label]=material
				var new_surface:=SurfaceTool.new()
				new_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surfaces[label]=new_surface
			var st: SurfaceTool=surfaces[label]
			var a: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
			var colors: PackedColorArray=a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
			var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vertices.size(): indices.append(i)
			# Reduction of thin curved details can leave a few triangles opposite their
			# interpolated normals; make their winding consistent before tangent bake.
			for triangle in range(0,indices.size(),3):
				var ia:=indices[triangle]
				var ib:=indices[triangle+1]
				var ic:=indices[triangle+2]
				if (vertices[ib]-vertices[ia]).cross(vertices[ic]-vertices[ia]).dot(normals[ia]+normals[ib]+normals[ic])>0:
					indices[triangle+1]=ic
					indices[triangle+2]=ib
			for index in indices:
				var p: Vector3=transform*vertices[index]
				var weights:=_weights(p,info.get("source",""),info.get("attachment",""),label)
				st.set_normal((transform.basis*normals[index]).normalized())
				st.set_uv(uv[index] if not uv.is_empty() else Vector2.ZERO)
				st.set_color(colors[index].linear_to_srgb() if not colors.is_empty() else Color.WHITE)
				var bone_ids:=PackedInt32Array([0,0,0,0])
				var bone_weights:=PackedFloat32Array([0,0,0,0])
				var slot:=0
				for name in weights:
					if weights[name]<=0: continue
					bone_ids[slot]=bones[name]
					bone_weights[slot]=weights[name]
					slot+=1
				st.set_bones(bone_ids)
				st.set_weights(bone_weights)
				st.add_vertex(p)
	for child in node.get_children(): _collect(child,transform)

func _initialize() -> void:
	model.name="DreamWisp"
	rig.name="Skeleton3D"
	model.add_child(rig)
	rig.owner=model
	manifest=JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"geometry_manifest.json")).parts
	var doc:=GLTFDocument.new()
	var input:=GLTFState.new()
	var result:=doc.append_from_file(SOURCE+"dream_wisp_geometry.glb",input)
	if result!=OK:
		push_error("Cannot read Blender geometry: "+error_string(result))
		quit(1)
		return
	var source:=doc.generate_scene(input)
	_rig()
	_collect(source)
	_finish()
	_animations()
	var state:=GLTFState.new()
	result=doc.append_from_scene(model,state)
	if result==OK: result=doc.write_to_filesystem(state,OUT)
	print("Dream fae: %d bones, %d material surfaces. %s" % [rig.get_bone_count(),surfaces.size(),error_string(result)])
	source.free()
	model.free()
	quit(0 if result==OK else 1)

func _poses(clip: String,t: float) -> Dictionary:
	var poses: Dictionary={}
	for label in bones: poses[label]=[rig.get_bone_rest(bones[label]).origin,Quaternion.IDENTITY]
	if clip=="RESET": return poses
	var breath:=sin(t*TAU)
	var pulse:=sin(t*PI)
	poses.pelvis[0]+=Vector3(0,0.13+breath*0.014,0)
	if clip=="attack": poses.pelvis[0]+=Vector3(0,pulse*0.03,pulse*0.07)
	poses.chest[1]=Quaternion(Vector3.RIGHT,-0.035+breath*0.015)
	poses.head[1]=Quaternion(Vector3.UP,breath*0.045)
	for side in [-1.0,1.0]:
		var s:="L" if side>0 else "R"
		var flap:=sin(t*TAU*(4 if clip=="idle" else 2))
		poses["wing_upper_"+s][1]=Quaternion.from_euler(Vector3(0,side*(0.10+flap*0.24),side*0.035*breath))
		poses["wing_lower_"+s][1]=Quaternion.from_euler(Vector3(0,side*(0.06+sin(t*TAU*(4 if clip=="idle" else 2)+0.45)*0.19),0))
		poses["upper_arm_"+s][1]=Quaternion.from_euler(Vector3(-0.08,0,side*(-0.10+breath*0.035)))
		poses["forearm_"+s][1]=Quaternion(Vector3.RIGHT,-0.18)
		poses["thigh_"+s][1]=Quaternion(Vector3.RIGHT,0.06+side*0.035)
		poses["shin_"+s][1]=Quaternion(Vector3.RIGHT,0.18+side*0.05)
		poses["foot_"+s][1]=Quaternion(Vector3.RIGHT,0.14)
		poses["skirt_"+s][1]=Quaternion.from_euler(Vector3(breath*0.055,0,side*0.025))
		poses["hair_"+s][1]=Quaternion(Vector3.RIGHT,breath*0.055)
		if clip=="walk":
			poses.chest[1]=Quaternion(Vector3.RIGHT,0.14)
			poses["thigh_"+s][1]=Quaternion(Vector3.RIGHT,-0.12+side*breath*0.07)
			poses["shin_"+s][1]=Quaternion(Vector3.RIGHT,0.40)
			poses["hair_"+s][1]=Quaternion(Vector3.RIGHT,0.20+breath*0.04)
		if clip=="attack":
			poses["upper_arm_"+s][1]=Quaternion.from_euler(Vector3(-pulse*1.00,side*pulse*0.25,side*pulse*0.12))
			poses["forearm_"+s][1]=Quaternion(Vector3.RIGHT,-0.15-pulse*0.35)
			poses["hand_"+s][1]=Quaternion(Vector3.RIGHT,pulse*0.40)
			poses.head[1]=Quaternion(Vector3.RIGHT,pulse*0.10)
		if clip=="hit":
			poses.chest[1]=Quaternion(Vector3.RIGHT,-pulse*0.32)
			poses["wing_upper_"+s][1]=Quaternion(Vector3.UP,side*pulse*0.60)
			poses.pelvis[0].z=-pulse*0.055
	poses.spell[1]=Quaternion(Vector3.BACK,breath*0.8)
	return poses
