extends Node3D

# 程序化「石砌水井」紀念碑（純視覺、實心 1 格佔位）。
# 由 building entity 以 [4,4,1,1] 無門擺在城鎮廣場中央；模型原點 = 該格中心，半徑控制在 1 格(=2.0)內。

func _ready() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.52, 0.51, 0.50)
	stone.roughness = 0.9
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.18, 0.38, 0.52)
	water.metallic = 0.2
	water.roughness = 0.15
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.43, 0.29, 0.15)
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.34, 0.17, 0.11)

	# 井身（矮石圓柱）
	_cylinder(0.55, 0.7, Vector3(0, 0.35, 0), stone)
	# 水面
	_cylinder(0.42, 0.06, Vector3(0, 0.62, 0), water)
	# 兩根支柱
	for sx in [-0.5, 0.5]:
		_box(Vector3(0.12, 1.0, 0.12), Vector3(sx, 1.1, 0), wood)
	# 山形屋頂（三角柱）
	var prism := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.4, 0.45, 0.6)
	prism.mesh = pm
	prism.material_override = roof
	prism.position = Vector3(0, 1.85, 0)
	add_child(prism)

func _cylinder(radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
