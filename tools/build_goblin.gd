extends SceneTree

# Reproducible, original mesh asset. Run with:
# godot --headless --path . --script tools/build_goblin.gd
# +Z is forward; the origin is on the soles. No billboard or external assets.
var _root: Node3D
var _m: Dictionary = {}

func _initialize() -> void:
	_m.skin = _material("Moss skin", Color("677744"), 0.86)
	_m.skin_dark = _material("Deep olive", Color("424e2e"), 0.9)
	_m.ear = _material("Ear cartilage", Color("777049"), 0.92)
	_m.leather = _material("Oxblood leather", Color("493026"), 0.88)
	_m.edge = _material("Worn leather edge", Color("866248"), 0.93)
	_m.cloth = _material("Rust red cloth", Color("6e3027"), 1.0)
	_m.iron = _material("Blackened iron", Color("42494b"), 0.53, 0.72)
	_m.steel = _material("Honed steel", Color("929c9a"), 0.34, 0.8)
	_m.brass = _material("Old brass", Color("ae8340"), 0.48, 0.7)
	_m.bone = _material("Old ivory", Color("d5c6a1"), 0.66)
	_m.mouth = _material("Mouth and sockets", Color("251e16"), 0.85)
	_m.eye = _material("Amber eyes", Color("deb63c"), 0.3)
	_m.eye.emission_enabled = true
	_m.eye.emission = Color("8c510b")
	_m.eye.emission_energy_multiplier = 0.25
	_root = Node3D.new()
	_root.name = "Goblin"
	var body := _pivot(_root, "Body", Vector3(0, 0.94, 0))
	_build_body(body)
	_build_head(body)
	_build_arm(body, -1.0)
	_build_arm(body, 1.0)
	_build_leg(-1.0)
	_build_leg(1.0)
	# Merge rigid pieces by material within each joint. Instances share these baked meshes.
	_merge_meshes(_root)
	# Authoring height is 0.94 (body) + 0.59 (neck) + 0.425 (crown).
	# Normalize at the top-level joints, keeping the sole origin at zero.
	var height_scale := 2.0 / (0.94 + 0.59 + 0.425)
	for joint in _root.get_children():
		joint.position *= height_scale
		joint.scale *= height_scale
	_root.set_script(load("res://presentation/monsters/monster_model.gd"))
	var packed := PackedScene.new()
	var result := packed.pack(_root)
	if result == OK:
		result = ResourceSaver.save(packed, "res://content/monsters/models/goblin.tscn")
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
	mesh.radial_segments = 16
	mesh.rings = 10
	var n := _mesh(parent, mesh, pos, mat)
	n.scale = size
	return n

func _bar(parent: Node3D, a: Vector3, b: Vector3, radius_a: float, radius_b: float, mat: Material, sides: int = 10) -> MeshInstance3D:
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
func _loft(parent: Node3D, sections: Array, mat: Material, sides: int = 20) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(sections.size() - 1):
		for i in sides:
			var a := _ring(sections[j], i, sides)
			var b := _ring(sections[j], i + 1, sides)
			var c := _ring(sections[j + 1], i + 1, sides)
			var d := _ring(sections[j + 1], i, sides)
			for v in [a, b, c, a, c, d]:
				var shade := 0.94 + 0.055 * sin(v.x * 41.0 + v.y * 27.0 + v.z * 33.0)
				st.set_color(Color(shade, shade, shade))
				st.add_vertex(v)
	st.generate_normals()
	st.index()
	_mesh(parent, st.commit(), Vector3.ZERO, mat)

func _ring(section: Array, i: int, sides: int) -> Vector3:
	var angle := float(i % sides) / sides * TAU
	return Vector3(cos(angle) * section[1], section[0], sin(angle) * section[2] + section[3])

# A closed beveled solid for ears, ragged cloth and weapon silhouettes (XY outline).
func _solid(parent: Node3D, outline: Array, depth: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
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
	_bar(head, Vector3(0, -0.07, 0), Vector3(0, 0.12, 0.01), 0.12, 0.14, _m.skin)
	_loft(head, [[0.015, 0.025, 0.04, 0.065], [0.05, 0.13, 0.11, 0.065], [0.13, 0.205, 0.15, 0.035], [0.24, 0.215, 0.17, 0], [0.34, 0.18, 0.14, -0.02], [0.40, 0.105, 0.09, -0.02], [0.425, 0.008, 0.008, -0.02]], _m.skin, 24)
	# Angular ears, recessed inner cartilage and cheek planes.
	for s in [-1.0, 1.0]:
		_solid(head, [Vector2(s * 0.16, 0.29), Vector2(s * 0.49, 0.365), Vector2(s * 0.35, 0.16), Vector2(s * 0.21, 0.13)], 0.050, _m.skin, Vector3(0, 0, -0.015))
		_solid(head, [Vector2(s * 0.215, 0.265), Vector2(s * 0.432, 0.327), Vector2(s * 0.32, 0.19), Vector2(s * 0.235, 0.17)], 0.016, _m.ear, Vector3(0, 0, 0.022))
		var cheek := _ellipsoid(head, Vector3(s * 0.149, 0.137, 0.124), Vector3(0.080, 0.044, 0.073), _m.skin_dark)
		cheek.rotation.z = s * 0.4
		var socket := _ellipsoid(head, Vector3(s * 0.105, 0.231, 0.151), Vector3(0.076, 0.040, 0.028), _m.mouth)
		socket.rotation.z = s * 0.18
		var eye := _ellipsoid(head, Vector3(s * 0.105, 0.229, 0.176), Vector3(0.051, 0.024, 0.018), _m.eye)
		eye.rotation.z = s * 0.18
		_ellipsoid(head, Vector3(s * 0.098, 0.229, 0.194), Vector3(0.009, 0.021, 0.006), _m.mouth)
		var brow := _ellipsoid(head, Vector3(s * 0.105, 0.266, 0.168), Vector3(0.099, 0.034, 0.044), _m.skin_dark)
		brow.rotation.z = s * 0.22
	# Hooked nose, nostrils, heavy muzzle, mouth slit, asymmetrical tusks.
	_ellipsoid(head, Vector3(0, 0.207, 0.171), Vector3(0.050, 0.108, 0.065), _m.skin)
	_ellipsoid(head, Vector3(0, 0.153, 0.23), Vector3(0.071, 0.044, 0.078), _m.skin)
	for s in [-1.0, 1.0]:
		_ellipsoid(head, Vector3(s * 0.045, 0.139, 0.274), Vector3(0.018, 0.011, 0.012), _m.mouth)
	_ellipsoid(head, Vector3(0, 0.089, 0.155), Vector3(0.135, 0.043, 0.065), _m.skin)
	_ellipsoid(head, Vector3(0, 0.057, 0.169), Vector3(0.127, 0.014, 0.047), _m.mouth)
	_ellipsoid(head, Vector3(0, 0.029, 0.148), Vector3(0.123, 0.032, 0.061), _m.skin_dark)
	for s in [-1.0, 1.0]:
		_bar(head, Vector3(s * 0.09, 0.041, 0.200), Vector3(s * 0.105, 0.114, 0.219), 0.019, 0.002, _m.bone)
	# A healed brow scar and a small brass ear ring.
	_bar(head, Vector3(-0.14, 0.29, 0.181), Vector3(-0.12, 0.19, 0.187), 0.006, 0.004, _m.ear, 6)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.023
	ring.outer_radius = 0.036
	ring.rings = 16
	ring.ring_segments = 8
	var earring := _mesh(head, ring, Vector3(0.32, 0.16, 0.035), _m.brass)
	earring.rotation.x = PI / 2.0

func _build_arm(body: Node3D, side: float) -> void:
	var arm := _pivot(body, "RightArm" if side < 0 else "LeftArm", Vector3(side * 0.32, 0.43, -0.005))
	_ellipsoid(arm, Vector3(side * 0.045, -0.045, 0), Vector3(0.13, 0.14, 0.13), _m.skin)
	_bar(arm, Vector3(side * 0.045, -0.04, 0), Vector3(side * 0.15, -0.29, 0.035), 0.105, 0.078, _m.skin)
	_ellipsoid(arm, Vector3(side * 0.15, -0.29, 0.035), Vector3.ONE * 0.08, _m.skin_dark)
	var forearm := _pivot(arm, "Forearm", Vector3(side * 0.15, -0.29, 0.035))
	_bar(forearm, Vector3.ZERO, Vector3(side * 0.015, -0.25, 0.10), 0.087, 0.06, _m.skin)
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
	_bar(leg, Vector3.ZERO, Vector3(side * 0.06, -0.32, 0.075), 0.12, 0.09, _m.cloth)
	_ellipsoid(leg, Vector3(side * 0.06, -0.34, 0.08), Vector3(0.095, 0.10, 0.09), _m.skin)
	var shin := _pivot(leg, "Shin", Vector3(side * 0.06, -0.35, 0.07))
	_bar(shin, Vector3.ZERO, Vector3(side * 0.045, -0.35, -0.06), 0.09, 0.058, _m.skin)
	_bar(shin, Vector3(side * 0.012, -0.10, -0.02), Vector3(side * 0.045, -0.37, -0.06), 0.095, 0.078, _m.leather)
	for i in 3:
		var y := -0.12 - i * 0.08
		_bar(shin, Vector3(side * 0.025, y, -0.035), Vector3(side * 0.025, y - 0.022, -0.039), 0.099 - i * 0.006, 0.098 - i * 0.006, _m.edge)
	_ellipsoid(shin, Vector3(side * 0.045, -0.414, 0.031), Vector3(0.10, 0.086, 0.18), _m.leather)
	_box(shin, Vector3(side * 0.045, -0.479, 0.031), Vector3(0.19, 0.042, 0.30), _m.mouth)

func _merge_meshes(parent: Node3D) -> void:
	var groups: Dictionary = {}
	for child in parent.get_children():
		if child is MeshInstance3D:
			var mat: Material = child.material_override
			if not groups.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[mat] = st
			var arrays: Array = child.mesh.surface_get_arrays(0)
			if arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].is_empty():
				var colors := PackedColorArray()
				colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
				colors.fill(Color.WHITE)
				arrays[Mesh.ARRAY_COLOR] = colors
			var source := ArrayMesh.new()
			source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			groups[mat].append_from(source, 0, child.transform)
			child.free()
		else:
			_merge_meshes(child)
	for mat in groups:
		var st: SurfaceTool = groups[mat]
		st.index()
		var node := _mesh(parent, st.commit(), Vector3.ZERO, mat)
		node.name = mat.resource_name.replace(" ", "")
