extends SceneTree

# Reproducible, original mesh asset. Run with:
# godot --headless --path . --script tools/build_goblin.gd
# +Z is forward; the origin is on the soles. No billboard or external assets.
var _root: Node3D
var _m: Dictionary = {}
const RigBuilder = preload("res://tools/goblin_rig.gd")

func _initialize() -> void:
	_m.skin = _material("Moss skin", Color("667254"), 0.86)
	_m.skin_dark = _material("Deep olive", Color("586449"), 0.9)
	_m.ear = _material("Ear cartilage", Color("777049"), 0.92)
	_m.leather = _material("Oxblood leather", Color("493026"), 0.88)
	_m.edge = _material("Worn leather edge", Color("72523b"), 0.93)
	_m.cloth = _material("Rust red cloth", Color("6e3027"), 1.0)
	_m.iron = _material("Blackened iron", Color("42494b"), 0.68, 0.65)
	_m.steel = _material("Honed steel", Color("929c9a"), 0.48, 0.8)
	_m.brass = _material("Old brass", Color("ae8340"), 0.58, 0.7)
	_m.bone = _material("Old ivory", Color("d5c6a1"), 0.66)
	_m.mouth = _material("Mouth and sockets", Color("251e16"), 0.85)
	_m.eye = _material("Amber eyes", Color("deb63c"), 0.3)
	_m.eye.emission_enabled = true
	_m.eye.emission = Color("8c510b")
	_m.eye.emission_energy_multiplier = 0.04
	RigBuilder.texture_materials(_m)
	_root = Node3D.new()
	_root.name = "Goblin"
	var body := _pivot(_root, "Body", Vector3(0, 0.94, 0))
	_build_body(body)
	_build_head(body)
	_build_arm(body, -1.0)
	_build_arm(body, 1.0)
	_build_leg(-1.0)
	_build_leg(1.0)
	# Bake all geometry in model space, then bind it to a real deformation rig.
	var height_scale := 2.0 / (0.94 + 0.59 + 0.425 * 0.9)
	for joint in _root.get_children():
		joint.position *= height_scale
		joint.scale *= height_scale
	var rig_builder := RigBuilder.new()
	rig_builder.build(_root, height_scale)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_scene(_root, state)
	if result == OK:
		result = document.write_to_filesystem(state, "res://content/monsters/models/goblin.glb")
	_root.free()
	print("Goblin mesh build: ", error_string(result))
	quit(0 if result == OK else 1)

func _material(label: String, color: Color, roughness: float, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = label
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metal
	mat.vertex_color_use_as_albedo = true
	return mat

func _pivot(parent: Node3D, label: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = label
	n.position = pos
	parent.add_child(n)
	n.owner = _root
	return n

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	n.owner = _root
	return n

func _ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var detail := maxf(size.x, maxf(size.y, size.z))
	mesh.radial_segments = 12 if detail < 0.04 else (20 if detail < 0.10 else 32)
	mesh.rings = 6 if detail < 0.04 else (12 if detail < 0.10 else 20)
	var n := _mesh(parent, mesh, pos, mat)
	n.scale = size
	return n

func _bar(parent: Node3D, a: Vector3, b: Vector3, radius_a: float, radius_b: float, mat: Material, sides: int = 20) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius_a
	mesh.top_radius = radius_b
	mesh.height = a.distance_to(b)
	mesh.radial_segments = sides
	mesh.rings = 1
	var n := _mesh(parent, mesh, (a + b) * 0.5, mat)
	var y := (b - a).normalized()
	var x := Vector3.FORWARD.cross(y).normalized()
	if x.length_squared() < 0.01:
		x = Vector3.RIGHT
	n.basis = Basis(x, y, x.cross(y).normalized())
	return n

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, pos, mat)

# Cross sections: y, x radius, z radius, forward offset. Sculpted profiles instead of stacked balls.
func _loft(parent: Node3D, sections: Array, mat: Material, sides: int = 40) -> void:
	# Catmull-Rom profiles retain anatomical landmarks while removing stepped rings.
	var rings: Array = []
	for j in range(sections.size() - 1):
		for k in 5:
			var t := float(k) / 5.0
			var row: Array = []
			for axis in 4:
				var a: float = sections[maxi(0, j - 1)][axis]
				var b: float = sections[j][axis]
				var c: float = sections[j + 1][axis]
				var d: float = sections[mini(sections.size() - 1, j + 2)][axis]
				row.append(0.5 * ((2*b) + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t))
			rings.append(row)
	rings.append(sections[-1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for j in range(rings.size() - 1):
		for i in sides:
			for ij in [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i+1,j+1), Vector2i(i,j), Vector2i(i+1,j+1), Vector2i(i,j+1)]:
				st.set_uv(Vector2(float(ij.x)/sides, float(ij.y)/(rings.size()-1)))
				st.set_color(Color.WHITE)
				st.add_vertex(_ring(rings[ij.y], ij.x, sides))
	st.generate_normals()
	st.generate_tangents()
	st.index()
	_mesh(parent, st.commit(), Vector3.ZERO, mat)

func _ring(section: Array, i: int, sides: int) -> Vector3:
	var angle := float(i % sides) / sides * TAU
	return Vector3(cos(angle) * maxf(0.002, section[1]), section[0], sin(angle) * maxf(0.002, section[2]) + section[3])

# One connected tube across shoulder/elbow/wrist or hip/knee/ankle.
func _limb(parent: Node3D, points: Array, radii: Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var rings: Array = []
	for j in range(points.size()-1):
		for k in 5:
			var t := float(k)/5.0
			var center: Vector3 = points[j].cubic_interpolate(points[j+1],points[maxi(0,j-1)],points[mini(points.size()-1,j+2)],t)
			var radius: Vector2 = radii[j].cubic_interpolate(radii[j+1],radii[maxi(0,j-1)],radii[mini(radii.size()-1,j+2)],t)
			var row: Array = []
			for i in 33:
				var angle := float(i)/32.0*TAU
				row.append(center + Vector3(cos(angle)*radius.x, 0, sin(angle)*radius.y))
			rings.append(row)
	var last: Array = []
	for i in 33:
		var angle := float(i)/32.0*TAU
		last.append(points[-1] + Vector3(cos(angle)*radii[-1].x,0,sin(angle)*radii[-1].y))
	rings.append(last)
	for j in range(rings.size()-1):
		for i in 32:
			for ij in [Vector2i(i,j),Vector2i(i+1,j+1),Vector2i(i+1,j),Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j+1)]:
				st.set_uv(Vector2(float(ij.x)/32.0,float(ij.y)/(rings.size()-1)))
				st.set_color(Color.WHITE)
				st.add_vertex(rings[ij.y][ij.x])
	st.generate_normals()
	st.generate_tangents()
	st.index()
	_mesh(parent, st.commit(), Vector3.ZERO, mat)

# A closed beveled solid for ears, ragged cloth and weapon silhouettes (XY outline).
func _solid(parent: Node3D, outline: Array, depth: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var center := Vector2.ZERO
	for p in outline:
		center += p
	center /= float(outline.size())
	for i in outline.size():
		var p: Vector2 = outline[i]
		var q: Vector2 = outline[(i + 1) % outline.size()]
		var a := Vector3(p.x, p.y, 0)
		var b := Vector3(q.x, q.y, 0)
		var front := Vector3(center.x, center.y, depth)
		var back := Vector3(center.x, center.y, -depth)
		# Orient the face outward regardless of mirrored outlines.
		var tri := [a, front, b, a, b, back]
		if (p - center).cross(q - center) < 0:
			tri = [a, b, front, a, back, b]
		for v in tri:
			st.set_color(Color.WHITE)
			st.add_vertex(v)
	st.generate_normals()
	st.index()
	return _mesh(parent, st.commit(), pos, mat)

func _build_body(body: Node3D) -> void:
	_loft(body, [[-0.15, 0.01, 0.01, 0], [-0.08, 0.23, 0.16, 0], [0.08, 0.23, 0.17, 0], [0.24, 0.26, 0.17, -0.015], [0.40, 0.34, 0.19, -0.025], [0.51, 0.30, 0.15, -0.025], [0.59, 0.13, 0.12, 0], [0.63, 0.01, 0.01, 0]], _m.skin)
	# A fitted sleeveless leather cuirass with laced front and a diagonal baldric.
	_loft(body, [[0.07, 0.245, 0.18, 0], [0.20, 0.265, 0.188, -0.01], [0.39, 0.35, 0.20, -0.02], [0.49, 0.285, 0.167, -0.018]], _m.leather)
	for s in [-1.0, 1.0]:
		_bar(body, Vector3(s * 0.12, 0.50, 0.12), Vector3(s * 0.29, 0.44, 0.10), 0.029, 0.031, _m.edge)
		for j in 5:
			var y := 0.12 + j * 0.058
			_ellipsoid(body, Vector3(s * 0.035, y, 0.183), Vector3.ONE * 0.012, _m.brass)
			_bar(body, Vector3(-0.035, y, 0.187), Vector3(0.035, y + 0.045, 0.187), 0.006, 0.006, _m.edge, 6)
	var sash := _box(body, Vector3(0.015, 0.31, 0.197), Vector3(0.073, 0.51, 0.032), _m.edge)
	sash.rotation.z = -0.83
	var back_sash := _box(body, Vector3(0.015, 0.31, -0.217), Vector3(0.073, 0.51, 0.032), _m.edge)
	back_sash.rotation.z = -0.83
	# Overlapping irregular skirt panels, each with real thickness.
	for i in 10:
		var angle := i * TAU / 10.0
		var panel := _solid(body, [Vector2(-0.085, 0.08), Vector2(-0.10, -0.20), Vector2(-0.02, -0.28 - 0.025 * sin(i * 5.0)), Vector2(0.095, -0.21), Vector2(0.075, 0.08)], 0.014, _m.cloth if i % 3 == 0 else _m.leather, Vector3(sin(angle) * 0.236, -0.02, cos(angle) * 0.175))
		panel.rotation.y = angle
	_loft(body, [[0.00, 0.255, 0.19, 0], [0.09, 0.255, 0.19, 0]], _m.leather)
	_box(body, Vector3(0.025, 0.045, 0.202), Vector3(0.105, 0.078, 0.025), _m.brass)
	_box(body, Vector3(0.025, 0.045, 0.218), Vector3(0.070, 0.045, 0.008), _m.mouth)
	_bar(body, Vector3(0.025, 0.01, 0.229), Vector3(0.025, 0.08, 0.229), 0.008, 0.008, _m.brass)
	_ellipsoid(body, Vector3(-0.26, -0.025, -0.045), Vector3(0.10, 0.13, 0.08), _m.leather)
	for i in 7:
		var angle := i * TAU / 7.0
		_ellipsoid(body, Vector3(sin(angle) * 0.26, 0.045, cos(angle) * 0.196), Vector3.ONE * 0.014, _m.brass)

func _build_head(body: Node3D) -> void:
	var head := _pivot(body, "Head", Vector3(0, 0.59, 0.045))
	head.scale = Vector3(0.85, 0.9, 0.88)
	var file := FileAccess.open("res://content/monsters/models/goblin_head.meshbin", FileAccess.READ)
	var count := file.get_32()
	var index_count := file.get_32()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	for i in count:
		var v := Vector3(file.get_float(),file.get_float(),file.get_float())
		vertices.append(v)
		var tint := Color.WHITE
		if absf(v.x)>0.22 and v.z>0.0:
			tint = Color(0.80,0.75,0.66)
		if v.y<0.075 and v.z>0.175:
			tint = Color(0.73,0.73,0.63)
		colors.append(tint)
		uv.append(Vector2(atan2(v.z,v.x)/TAU+0.5,(v.y+0.11)/0.56))
	for i in count:
		normals.append(Vector3(file.get_float(),file.get_float(),file.get_float()))
	var indices := PackedInt32Array()
	for i in index_count:
		indices.append(file.get_32())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var sculpt := ArrayMesh.new()
	sculpt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_mesh(head,sculpt,Vector3.ZERO,_m.skin)
	for side in [-1.0,1.0]:
		# Small inset eyeballs with amber irises, round pupils, and subtle wet highlights.
		_ellipsoid(head,Vector3(side*0.091,0.220,0.149),Vector3(0.034,0.013,0.026),_m.bone)
		_ellipsoid(head,Vector3(side*0.088,0.219,0.172),Vector3(0.017,0.012,0.006),_m.eye)
		_ellipsoid(head,Vector3(side*0.088,0.219,0.178),Vector3(0.006,0.009,0.003),_m.mouth)
		_bar(head,Vector3(side*0.084,0.044,0.20),Vector3(side*0.094,0.097,0.220),0.012,0.001,_m.bone)
	# A healed brow scar and a small brass ear ring.
	_bar(head, Vector3(-0.14, 0.29, 0.181), Vector3(-0.12, 0.19, 0.187), 0.006, 0.004, _m.ear, 6)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.023
	ring.outer_radius = 0.036
	ring.rings = 16
	ring.ring_segments = 8
	var earring := _mesh(head, ring, Vector3(0.32, 0.24, 0.012), _m.brass)
	earring.rotation.x = PI / 2.0

func _build_arm(body: Node3D, side: float) -> void:
	var arm := _pivot(body, "RightArm" if side < 0 else "LeftArm", Vector3(side * 0.32, 0.43, -0.005))
	_limb(arm, [Vector3(side*0.02,0.065,0), Vector3(side*0.045,-0.04,0), Vector3(side*0.09,-0.15,0.01), Vector3(side*0.15,-0.29,0.035), Vector3(side*0.155,-0.37,0.06), Vector3(side*0.165,-0.54,0.135), Vector3(side*0.165,-0.60,0.155)], [Vector2(0.065,0.060),Vector2(0.12,0.115),Vector2(0.10,0.095),Vector2(0.067,0.071),Vector2(0.089,0.082),Vector2(0.054,0.054),Vector2(0.045,0.045)], _m.skin)
	var forearm := _pivot(arm, "Forearm", Vector3(side * 0.15, -0.29, 0.035))
	_bar(forearm, Vector3(side * 0.004, -0.08, 0.032), Vector3(side * 0.014, -0.23, 0.09), 0.092, 0.074, _m.leather)
	for j in 3:
		var y := -0.10 - j * 0.053
		_bar(forearm, Vector3(0, y, -y * 0.4), Vector3(0, y - 0.017, -y * 0.4 + 0.007), 0.094 - j * 0.007, 0.094 - j * 0.007, _m.edge)
	var hand := _pivot(forearm, "Hand", Vector3(side * 0.015, -0.29, 0.12))
	_ellipsoid(hand, Vector3.ZERO, Vector3(0.075, 0.086, 0.061), _m.skin)
	for i in 4:
		_ellipsoid(hand, Vector3(-0.047 + i * 0.03, -0.027, 0.044), Vector3(0.017, 0.045, 0.025), _m.skin_dark)
	_ellipsoid(hand, Vector3(-side * 0.068, 0.016, 0.025), Vector3(0.024, 0.052, 0.029), _m.skin)
	if side < 0:
		_build_sword(hand)
	else:
		# Salvaged layered iron pauldron with rivets and three battered spikes.
		_ellipsoid(arm, Vector3(0.025, 0.018, -0.007), Vector3(0.19, 0.105, 0.18), _m.iron)
		for i in 3:
			var x := -0.065 + i * 0.075
			_bar(arm, Vector3(x, 0.07, -0.025), Vector3(x + 0.035, 0.23 - i * 0.02, -0.025), 0.033, 0.001, _m.steel, 6)
		for i in 4:
			_ellipsoid(arm, Vector3(-0.09 + i * 0.075, 0.0, 0.145), Vector3.ONE * 0.018, _m.brass)
		_build_shield(hand)

func _build_sword(hand: Node3D) -> void:
	var weapon := _pivot(hand, "Cleaver", Vector3(0, 0, 0.035))
	weapon.rotation_degrees = Vector3(-16, 0, 25)
	_bar(weapon, Vector3(0, -0.12, 0), Vector3(0, 0.12, 0), 0.027, 0.025, _m.leather)
	for i in 6:
		_bar(weapon, Vector3(0, -0.10 + i * 0.036, 0), Vector3(0, -0.092 + i * 0.036, 0), 0.029, 0.029, _m.edge)
	_ellipsoid(weapon, Vector3(0, -0.13, 0), Vector3(0.041, 0.037, 0.037), _m.brass)
	_box(weapon, Vector3(0, 0.135, 0), Vector3(0.24, 0.043, 0.057), _m.iron)
	_solid(weapon, [Vector2(-0.045, 0.15), Vector2(-0.06, 0.61), Vector2(-0.16, 0.79), Vector2(0.105, 0.68), Vector2(0.095, 0.41), Vector2(0.07, 0.385), Vector2(0.092, 0.365), Vector2(0.07, 0.15)], 0.023, _m.iron)
	_solid(weapon, [Vector2(0.045, 0.16), Vector2(0.07, 0.36), Vector2(0.05, 0.39), Vector2(0.073, 0.415), Vector2(0.082, 0.665), Vector2(-0.16, 0.79), Vector2(0.105, 0.68), Vector2(0.095, 0.41), Vector2(0.07, 0.385), Vector2(0.092, 0.365), Vector2(0.07, 0.15)], 0.006, _m.steel, Vector3(0, 0, 0.022))

func _build_shield(hand: Node3D) -> void:
	var shield := _pivot(hand, "Buckler", Vector3(0.025, 0.06, 0.13))
	shield.rotation_degrees = Vector3(-8, 12, -8)
	var outline: Array = []
	for i in 12:
		var a := float(i) / 12.0 * TAU
		outline.append(Vector2(cos(a) * 0.25, sin(a) * 0.29))
	_solid(shield, outline, 0.055, _m.iron)
	var inset: Array = []
	for p in outline:
		inset.append(p * 0.87)
	_solid(shield, inset, 0.026, _m.leather, Vector3(0, 0, 0.044))
	_ellipsoid(shield, Vector3(0, 0, 0.071), Vector3(0.09, 0.09, 0.06), _m.steel)
	for i in 8:
		var a := i * TAU / 8.0
		_ellipsoid(shield, Vector3(cos(a) * 0.208, sin(a) * 0.24, 0.035), Vector3.ONE * 0.013, _m.brass)
	for s in [-1.0, 1.0]:
		_box(shield, Vector3(s * 0.13, 0, 0.073), Vector3(0.022, 0.39, 0.014), _m.edge)

func _build_leg(side: float) -> void:
	var leg := _pivot(_root, "RightLeg" if side < 0 else "LeftLeg", Vector3(side * 0.15, 0.85, 0))
	_limb(leg, [Vector3(0,0.04,0),Vector3(side*0.025,-0.10,0.025),Vector3(side*0.06,-0.28,0.07),Vector3(side*0.06,-0.35,0.07),Vector3(side*0.075,-0.47,0.035),Vector3(side*0.105,-0.70,0.01)], [Vector2(0.115,0.125),Vector2(0.122,0.12),Vector2(0.083,0.087),Vector2(0.08,0.082),Vector2(0.087,0.085),Vector2(0.052,0.055)], _m.skin)
	_bar(leg, Vector3(0,0.06,0), Vector3(side*0.05,-0.24,0.058), 0.145,0.117,_m.cloth)
	var shin := _pivot(leg, "Shin", Vector3(side * 0.06, -0.35, 0.07))
	_bar(shin, Vector3(side * 0.012, -0.10, -0.02), Vector3(side * 0.045, -0.37, -0.06), 0.113, 0.094, _m.leather)
	for i in 3:
		var y := -0.12 - i * 0.08
		_bar(shin, Vector3(side * 0.025, y, -0.035), Vector3(side * 0.025, y - 0.022, -0.039), 0.117 - i * 0.007, 0.116 - i * 0.007, _m.edge)
	_ellipsoid(shin, Vector3(side * 0.045, -0.414, 0.031), Vector3(0.10, 0.086, 0.18), _m.leather)
	_box(shin, Vector3(side * 0.045, -0.479, 0.031), Vector3(0.19, 0.042, 0.30), _m.mouth)
