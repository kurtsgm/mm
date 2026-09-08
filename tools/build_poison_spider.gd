extends SceneTree

# Original, deterministic eight-legged creature. +Z forward; resting tarsi at y=0.
# Offline only: godot --headless --path . --script tools/build_poison_spider.gd
const OUT := "res://content/monsters/models/poison_spider.glb"
var model := Node3D.new()
var rig := Skeleton3D.new()
var bones: Dictionary = {}
var rests: Dictionary = {}
var surfaces: Dictionary = {}
var materials: Dictionary = {}
var legs: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var hair_count := 0

func _initialize() -> void:
	rng.seed = 92071
	model.name = "PoisonSpider"
	rig.name = "Skeleton3D"
	model.add_child(rig)
	rig.owner = model
	_material("Carapace", Color("514a32"), 0.43)
	_material("Abdomen", Color("786246"), 0.76)
	_material("JointMembrane", Color("292722"), 0.86)
	_material("Fangs", Color("382b20"), 0.28)
	_material("Eyes", Color("471d0d"), 0.10)
	_material("Setae", Color("62513c"), 0.95)
	_material("Venom", Color("849b35"), 0.17)
	_textures()
	_bone("root", "", Vector3.ZERO)
	_bone("body", "root", Vector3(0, 0.35, 0.16))
	_bone("abdomen", "body", Vector3(0, 0.41, -0.29))
	_body()
	for side in [-1.0, 1.0]:
		for pair in 4:
			_leg(side, pair)
		_face(side)
	_finish()
	_animations()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_scene(model, state)
	if result == OK:
		result = document.write_to_filesystem(state, OUT)
	print("Poison spider: %d bones, %d material surfaces, %d modeled setae. %s" % [rig.get_bone_count(), surfaces.size(), hair_count, error_string(result)])
	model.free()
	quit(0 if result == OK else 1)

func _material(label: String, color: Color, roughness: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.resource_name = label
	mat.albedo_color = color
	mat.roughness = roughness
	mat.vertex_color_use_as_albedo = true
	materials[label] = mat
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	surfaces[label] = st

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

func _vertex(mat: String, bone: String, p: Vector3, normal: Vector3, uv: Vector2, color: Color) -> void:
	var st: SurfaceTool = surfaces[mat]
	st.set_normal(normal)
	st.set_uv(uv)
	st.set_color(color)
	st.set_bones(PackedInt32Array([bones[bone], 0, 0, 0]))
	st.set_weights(PackedFloat32Array([1, 0, 0, 0]))
	st.add_vertex(p)

# Smooth asymmetric organic surfaces with vertex-painted dorsal markings.
func _ellipsoid(center: Vector3, size: Vector3, mat: String, bone: String, kind: String = "", segments: int = 40, rings: int = 24) -> void:
	var verts: Array[Vector3] = []
	var colors: Array[Color] = []
	for j in range(rings + 1):
		for i in range(segments + 1):
			var v := float(j) / rings
			var u := float(i) / segments
			var n := Vector3(sin(v*PI)*cos(u*TAU), cos(v*PI), sin(v*PI)*sin(u*TAU))
			var p := n * size
			var color := Color.WHITE
			if kind == "abdomen":
				p.x *= 1.0 - n.z*0.13
				p.y += 0.003*sin(n.z*58.0)*pow(absf(n.x), 3.0)
				var leaf := absf(n.x) + 0.14*sin(n.z*27.0+absf(n.x)*8.0)
				var dorsal := smoothstep(0.30, 0.68, n.y)
				var marking := (1.0-smoothstep(0.18, 0.25, leaf))*dorsal
				color = Color.WHITE.lerp(Color("211c18"), marking*0.92)
				var edge := (1.0-smoothstep(0.025,0.07,absf(leaf-0.30)))*dorsal
				color = color.lerp(Color("d9b676"), edge*0.8)
				var spots := pow(maxf(0.0, sin(n.z*39.0+n.x*7.0)), 12.0)*smoothstep(0.45,0.6,absf(n.x))*dorsal
				color = color.lerp(Color("d2ac68"), spots*0.6)
			elif kind == "carapace":
				var groove := pow(maxf(0.0, cos(atan2(n.x,n.z)*10.0 + n.z*3.0)), 18.0)
				p.y -= groove*0.006*smoothstep(0.1,0.6,n.y)
				color = Color.WHITE.lerp(Color("29281f"), groove*0.35)
				color = color.lerp(Color("c8aa6e"), pow(maxf(0.0,n.y),4.0)*0.30)
			verts.append(center + p)
			colors.append(color)
	for j in rings:
		for i in segments:
			# Godot front faces are clockwise.
			for index in [j*(segments+1)+i, (j+1)*(segments+1)+i+1, j*(segments+1)+i+1, j*(segments+1)+i, (j+1)*(segments+1)+i, (j+1)*(segments+1)+i+1]:
				var p := verts[index]
				var n := ((p-center)/(size*size)).normalized()
				_vertex(mat,bone,p,n,Vector2(float(index%(segments+1))/segments,float(index/(segments+1) as int)/rings),colors[index])

# Curved tapered cuticle, claws and true geometry hairs; no alpha cards.
func _tube(points: Array[Vector3], radii: Array[float], mat: String, bone: String, sides: int = 16, color: Color = Color.WHITE) -> void:
	var verts: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var initial_tangent := (points[1]-points[0]).normalized()
	var reference := Vector3.UP if absf(initial_tangent.y)<0.95 else Vector3.RIGHT
	var frame_x := initial_tangent.cross(reference).normalized()
	for j in points.size():
		var tangent := (points[mini(j+1,points.size()-1)]-points[maxi(0,j-1)]).normalized()
		# Parallel transport avoids sudden frame flips in nearly vertical hairs.
		var x := (frame_x-tangent*frame_x.dot(tangent)).normalized()
		var y := tangent.cross(x).normalized()
		frame_x = x
		for i in range(sides+1):
			var a := float(i)/sides*TAU
			var n := x*cos(a)+y*sin(a)
			verts.append(points[j]+n*radii[j])
			normals.append(n)
	for j in range(points.size()-1):
		for i in sides:
			for index in [j*(sides+1)+i,(j+1)*(sides+1)+i,j*(sides+1)+i+1,j*(sides+1)+i+1,(j+1)*(sides+1)+i,(j+1)*(sides+1)+i+1]:
				_vertex(mat,bone,verts[index],normals[index],Vector2(float(index%(sides+1))/sides,float(index/(sides+1))/(points.size()-1)),color)

func _segment(a: Vector3, b: Vector3, radius: float, bone: String, hairs: int = 70) -> void:
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	var axis := (b-a).normalized()
	var cross_axis := axis.cross(Vector3.UP).normalized()
	for i in 13:
		var t := float(i)/12.0
		points.append(a.lerp(b,t)+cross_axis*sin(t*PI)*radius*0.22)
		radii.append(radius*(0.60+sin(t*PI)*0.42)*(1.0-t*0.36))
	_tube(points,radii,"Carapace",bone,20)
	# Pale joint collars, small annulations and dorsal sensory spines.
	for t in [0.14,0.82,0.88]:
		var mid := a.lerp(b,t)
		var r: float = radius*(0.60+sin(t*PI)*0.42)*(1.0-t*0.36)+0.001
		_tube([mid-axis*0.004,mid,mid+axis*0.004],[r*0.97,r*1.04,r*0.97],"Carapace",bone,20,Color("c6b283"))
	for i in hairs:
		var t := rng.randf_range(0.1,0.93)
		var angle := rng.randf()*TAU
		var n := cross_axis*cos(angle)+axis.cross(cross_axis)*sin(angle)
		var r := radius*(0.60+sin(t*PI)*0.42)*(1.0-t*0.36)
		var p := a.lerp(b,t)+cross_axis*sin(t*PI)*radius*0.22+n*r
		_hair(p,n*0.65+axis*0.5,rng.randf_range(0.014,0.038),bone,0.0010)
	for i in 5:
		var t := 0.20+i*0.13
		var p := a.lerp(b,t)+Vector3.UP*radius*0.85
		_hair(p,Vector3.UP*0.8+axis*0.35,0.04,"%s" % bone,0.0025)

func _hair(p: Vector3, direction: Vector3, length_value: float, bone: String, radius: float) -> void:
	var d := direction.normalized()*length_value
	d.y = maxf(d.y, 0.001-p.y)
	var tip := p+d+Vector3(0,-length_value*0.12,0)
	tip.y = maxf(0.0002,tip.y)
	_tube([p,p+d*0.55,tip],[radius,radius*0.55,0.00003],"Setae",bone,3)
	hair_count += 1

func _fuzz(center: Vector3, size: Vector3, bone: String, count: int) -> void:
	for i in count:
		var y := rng.randf_range(-0.70,1.0)
		var a := rng.randf()*TAU
		var n := Vector3(sqrt(1-y*y)*cos(a),y,sqrt(1-y*y)*sin(a))
		var p := center+n*size
		if bone == "abdomen": p.x = center.x+(p.x-center.x)*(1.0-n.z*0.13)
		_hair(p,n+Vector3(0,0,-0.4),rng.randf_range(0.009,0.026),bone,0.0008)

func _body() -> void:
	_ellipsoid(Vector3(0,0.41,-0.29),Vector3(0.235,0.222,0.335),"Abdomen","abdomen","abdomen",128,80)
	_ellipsoid(Vector3(0,0.355,0.15),Vector3(0.195,0.133,0.25),"Carapace","body","carapace",96,64)
	_ellipsoid(Vector3(0,0.29,0.12),Vector3(0.142,0.051,0.182),"JointMembrane","body")
	_ellipsoid(Vector3(0,0.36,-0.08),Vector3(0.080,0.076,0.10),"JointMembrane","body")
	_fuzz(Vector3(0,0.41,-0.29),Vector3(0.237,0.223,0.336),"abdomen",1400)
	_fuzz(Vector3(0,0.355,0.15),Vector3(0.197,0.134,0.252),"body",350)
	# Central foveal depression and short spinnerets under the rear abdomen.
	_ellipsoid(Vector3(0,0.487,0.11),Vector3(0.012,0.002,0.045),"JointMembrane","body","",24,12)
	for side in [-1.0,1.0]:
		_tube([Vector3(side*0.06,0.32,-0.56),Vector3(side*0.068,0.29,-0.63),Vector3(side*0.065,0.275,-0.68)],[0.025,0.015,0.004],"Carapace","abdomen")

func _leg(side: float, pair: int) -> void:
	var suffix := ("L" if side>0 else "R")+str(pair+1)
	var hips := [Vector3(0.14,0.35,0.30),Vector3(0.18,0.34,0.20),Vector3(0.18,0.335,0.09),Vector3(0.145,0.33,-0.02)]
	var knees := [Vector3(0.41,0.48,0.58),Vector3(0.57,0.50,0.31),Vector3(0.56,0.46,-0.16),Vector3(0.43,0.44,-0.48)]
	var ankles := [Vector3(0.59,0.115,0.74),Vector3(0.70,0.11,0.37),Vector3(0.70,0.10,-0.32),Vector3(0.59,0.10,-0.69)]
	var feet := [Vector3(0.65,0.004,0.83),Vector3(0.77,0.004,0.40),Vector3(0.77,0.004,-0.36),Vector3(0.65,0.004,-0.77)]
	var points: Array[Vector3] = [hips[pair],knees[pair],ankles[pair],feet[pair]]
	for i in points.size(): points[i].x *= side
	var labels: Array[String] = []
	for i in 4:
		var label: String = ["femur_","tibia_","tarsus_","foot_"][i]+suffix
		_bone(label,"body" if i==0 else labels[i-1],points[i])
		labels.append(label)
		if i < 3:
			_ellipsoid(points[i],Vector3.ONE*[0.039,0.028,0.014][i],"JointMembrane",label,"",24,16)
			_segment(points[i],points[i+1],[0.038,0.025,0.012][i],label,80 if i<2 else 28)
	# Paired terminal claws terminate on the floor without penetrating it.
	for spread in [-1.0,1.0]:
		var p := points[3]
		_tube([p,p+Vector3(spread*0.008,0.003,0.013),p+Vector3(spread*0.008,-0.004,0.025)],[0.005,0.003,0.0001],"Fangs",labels[3],8)
	legs.append({"labels":labels,"points":points,"side":side,"pair":pair})

func _face(side: float) -> void:
	var suffix := "L" if side>0 else "R"
	# Four eyes per side on the front and lateral brow, in genuine 3D sockets.
	for spec in [[0.044,0.404,0.367,0.027],[0.101,0.393,0.348,0.019],[0.133,0.425,0.299,0.014],[0.074,0.454,0.294,0.014]]:
		var p := Vector3(side*spec[0],spec[1],spec[2])
		var r: float = spec[3]
		_ellipsoid(p,Vector3(r*1.29,r*1.20,r*0.97),"JointMembrane","body","",32,20)
		_ellipsoid(p+Vector3(0,0.002,0.009),Vector3(r,r,r*0.85),"Eyes","body","",40,28)
	var fang := "fang_"+suffix
	_bone(fang,"body",Vector3(side*0.065,0.30,0.352))
	_ellipsoid(Vector3(side*0.067,0.297,0.385),Vector3(0.046,0.060,0.065),"Carapace",fang)
	_tube([Vector3(side*0.07,0.277,0.408),Vector3(side*0.076,0.247,0.450),Vector3(side*0.061,0.211,0.477),Vector3(side*0.034,0.185,0.483),Vector3(side*0.018,0.184,0.468)],[0.028,0.023,0.016,0.009,0.0003],"Fangs",fang,24)
	_ellipsoid(Vector3(side*0.039,0.195,0.481),Vector3(0.006,0.009,0.005),"Venom",fang,"",20,12)
	var palp := "palp_"+suffix
	var tip := "palp_tip_"+suffix
	var a := Vector3(side*0.14,0.315,0.32)
	var b := Vector3(side*0.218,0.268,0.414)
	var c := Vector3(side*0.186,0.22,0.502)
	_bone(palp,"body",a)
	_bone(tip,palp,b)
	_segment(a,b,0.027,palp,45)
	_segment(b,c,0.018,tip,35)
	_ellipsoid(c,Vector3(0.019,0.018,0.025),"Carapace",tip)

# Tileable micro-cuticle height field; macro stripes are painted on the body vertices.
func _textures() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 513
	noise.frequency = 0.25
	var size := 512
	var heights := PackedFloat32Array()
	heights.resize(size*size)
	for y in size:
		for x in size:
			var u := float(x)/size
			var v := float(y)/size
			var n := lerpf(lerpf(noise.get_noise_2d(x,y),noise.get_noise_2d(x-size,y),u),lerpf(noise.get_noise_2d(x,y-size),noise.get_noise_2d(x-size,y-size),u),v)
			heights[y*size+x] = n*0.65+0.10*sin(u*TAU*72.0+sin(v*TAU*12.0))*sin(v*TAU*64.0)
	var albedo := Image.create(size,size,false,Image.FORMAT_RGB8)
	var normal := Image.create(size,size,false,Image.FORMAT_RGB8)
	var rough := Image.create(size,size,false,Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var h := heights[y*size+x]
			var value := 0.87+h*0.26
			albedo.set_pixel(x,y,Color(value,value,value))
			var dx := heights[y*size+posmod(x+1,size)]-heights[y*size+posmod(x-1,size)]
			var dy := heights[posmod(y+1,size)*size+x]-heights[posmod(y-1,size)*size+x]
			var n := Vector3(-dx*1.5,-dy*1.5,1).normalized()
			normal.set_pixel(x,y,Color(n.x*0.5+0.5,n.y*0.5+0.5,n.z*0.5+0.5))
			var rv := 0.8+h*0.3
			rough.set_pixel(x,y,Color(rv,rv,rv))
	# Embed in the GLB only: rebuilding does not leave duplicate texture files.
	for img in [albedo,normal,rough]: img.generate_mipmaps()
	var color_tex := ImageTexture.create_from_image(albedo)
	var normal_tex := ImageTexture.create_from_image(normal)
	var rough_tex := ImageTexture.create_from_image(rough)
	for label in ["Carapace","Abdomen","JointMembrane","Fangs"]:
		var mat: StandardMaterial3D = materials[label]
		mat.albedo_texture = color_tex
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
		mat.normal_scale = 0.50 if label=="Abdomen" else 0.32
		mat.roughness_texture = rough_tex
		mat.uv1_scale = Vector3(2,2,1)

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

# Offline two-link IK: bake fixed-length legs and floor contacts into normal glTF tracks.
func _leg_pose(leg: Dictionary, clip: String, t: float, shift: Vector3) -> Array[Vector3]:
	var p: Array[Vector3] = leg.points
	var hip := p[0]+shift
	var foot := p[3]
	if clip=="walk":
		var phase := fposmod(t + (0.5 if (leg.pair + (1 if leg.side>0 else 0))%2==0 else 0.0),1.0)
		# Half stance slides back relative to the moving root, half swing returns above ground.
		if phase<0.5:
			foot.z += lerpf(0.075,-0.075,phase*2.0)
		else:
			var swing := (phase-0.5)*2.0
			foot.z += lerpf(-0.075,0.075,swing)
			foot.y += sin(swing*PI)*0.075
	elif clip=="attack" and leg.pair==0:
		var lift := sin(PI*t)
		foot.y += lift*0.17
		foot.z += lift*0.10
	var ankle := foot+(p[2]-p[3])
	var delta := ankle-hip
	var d := delta.length()
	var axis := delta.normalized()
	var l1 := p[0].distance_to(p[1])
	var l2 := p[1].distance_to(p[2])
	var a := (l1*l1-l2*l2+d*d)/(2.0*d)
	var height := sqrt(maxf(0.0,l1*l1-a*a))
	var pole := p[1]-p[0]
	pole = (pole-axis*pole.dot(axis)).normalized()
	return [hip,hip+axis*a+pole*height,ankle,foot]

func _poses(clip: String, t: float) -> Dictionary:
	var poses: Dictionary = {}
	for label in bones:
		poses[label] = [rig.get_bone_rest(bones[label]).origin,Quaternion.IDENTITY]
	if clip=="RESET": return poses
	var shift := Vector3.ZERO
	if clip=="idle": shift.y = sin(t*TAU)*0.003
	if clip=="walk": shift.y = (1.0-cos(t*TAU*2.0))*0.004
	if clip=="attack": shift = Vector3(0,sin(t*PI)*0.045,sin(t*PI)*0.12)
	if clip=="hit": shift = Vector3(sin(t*TAU*2.0)*sin(t*PI)*0.025,-sin(t*PI)*0.035,-sin(t*PI)*0.04)
	poses.body[0] += shift
	poses.abdomen[1] = Quaternion(Vector3.RIGHT,sin(t*TAU)*0.012 if clip=="idle" else sin(t*PI)*0.045)
	for leg in legs:
		var posed := _leg_pose(leg,clip,t,shift)
		var parent_rotation := Quaternion.IDENTITY
		var parent_position: Vector3 = rests.body+shift
		for i in 4:
			var label: String = leg.labels[i]
			var global_rotation := parent_rotation
			if i<3:
				global_rotation = Quaternion((leg.points[i+1]-leg.points[i]).normalized(),(posed[i+1]-posed[i]).normalized())
			poses[label] = [parent_rotation.inverse()*(posed[i]-parent_position),parent_rotation.inverse()*global_rotation]
			parent_rotation = global_rotation
			parent_position = posed[i]
	for side in [-1.0,1.0]:
		var suffix := "L" if side>0 else "R"
		poses["palp_"+suffix][1] = Quaternion.from_euler(Vector3(sin(t*TAU)*0.065,side*sin(t*TAU+0.6)*0.08,0))
		poses["palp_tip_"+suffix][1] = Quaternion(Vector3.RIGHT,sin(t*TAU+0.5)*0.10)
		if clip=="attack": poses["fang_"+suffix][1] = Quaternion.from_euler(Vector3(-sin(t*PI)*0.45,side*sin(t*PI)*0.22,0))
	return poses

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
