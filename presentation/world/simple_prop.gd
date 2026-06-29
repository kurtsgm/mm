extends Node3D

# 參數化室內家具/道具（純視覺）。由地圖 decoration 以 model id "prop_<kind>" 擺到格中心。
# 每個 prop 都做在原點周圍、約 1 格(2.0)內，矮於牆高。各室內 subagent 只引用 id、不寫 3D。

@export var kind: String = "barrel"

const WOOD := Color(0.45, 0.30, 0.16)
const DARKWOOD := Color(0.32, 0.21, 0.12)
const STONE := Color(0.55, 0.54, 0.52)
const METAL := Color(0.28, 0.29, 0.32)
const CLOTH := Color(0.55, 0.18, 0.18)
const GOLD := Color(0.80, 0.66, 0.28)
const FIRE := Color(1.0, 0.55, 0.15)

func _ready() -> void:
	match kind:
		"counter": _counter()
		"shelf": _shelf()
		"barrel": _barrel()
		"crate": _crate()
		"table": _table()
		"brazier": _brazier()
		"anvil": _anvil()
		"altar": _altar()
		"bookshelf": _bookshelf()
		"bed": _bed()
		_: _crate()

func _counter() -> void:
	_box(Vector3(1.6, 0.9, 0.6), Vector3(0, 0.45, 0), _m(DARKWOOD))
	_box(Vector3(1.7, 0.1, 0.7), Vector3(0, 0.95, 0), _m(WOOD))

func _shelf() -> void:
	_box(Vector3(1.4, 1.6, 0.35), Vector3(0, 0.8, 0), _m(WOOD))
	for y in [0.55, 1.05, 1.45]:
		_box(Vector3(1.3, 0.06, 0.34), Vector3(0, y, 0.01), _m(DARKWOOD))

func _barrel() -> void:
	_cyl(0.35, 0.9, Vector3(0, 0.45, 0), _m(WOOD))
	_cyl(0.37, 0.1, Vector3(0, 0.25, 0), _m(METAL))
	_cyl(0.37, 0.1, Vector3(0, 0.7, 0), _m(METAL))

func _crate() -> void:
	_box(Vector3(0.7, 0.7, 0.7), Vector3(0, 0.35, 0), _m(WOOD))

func _table() -> void:
	_box(Vector3(1.4, 0.1, 0.8), Vector3(0, 0.75, 0), _m(WOOD))
	for sx in [-0.6, 0.6]:
		for sz in [-0.3, 0.3]:
			_box(Vector3(0.1, 0.75, 0.1), Vector3(sx, 0.37, sz), _m(DARKWOOD))

func _brazier() -> void:
	_cyl(0.12, 0.9, Vector3(0, 0.45, 0), _m(METAL))
	_cyl(0.35, 0.25, Vector3(0, 0.95, 0), _m(METAL))
	var fire := _m(FIRE)
	fire.emission_enabled = true
	fire.emission = FIRE
	fire.emission_energy_multiplier = 2.0
	_cyl(0.28, 0.2, Vector3(0, 1.12, 0), fire)
	var l := OmniLight3D.new()
	l.light_color = FIRE
	l.omni_range = 5.0
	l.light_energy = 1.6
	l.position = Vector3(0, 1.3, 0)
	add_child(l)

func _anvil() -> void:
	_box(Vector3(0.5, 0.5, 0.4), Vector3(0, 0.25, 0), _m(DARKWOOD))
	_box(Vector3(0.9, 0.25, 0.4), Vector3(0, 0.62, 0), _m(METAL))
	_box(Vector3(0.5, 0.18, 0.3), Vector3(0.32, 0.83, 0), _m(METAL))

func _altar() -> void:
	_box(Vector3(1.2, 1.0, 0.7), Vector3(0, 0.5, 0), _m(STONE))
	_box(Vector3(1.3, 0.12, 0.8), Vector3(0, 1.05, 0), _m(STONE))
	var g := _m(GOLD)
	g.metallic = 0.6
	g.roughness = 0.3
	_box(Vector3(0.12, 0.6, 0.12), Vector3(0, 1.4, 0), g)
	_box(Vector3(0.4, 0.12, 0.12), Vector3(0, 1.32, 0), g)

func _bookshelf() -> void:
	_box(Vector3(1.4, 2.0, 0.4), Vector3(0, 1.0, 0), _m(DARKWOOD))
	var cols := [Color(0.5, 0.2, 0.2), Color(0.2, 0.35, 0.5), Color(0.3, 0.45, 0.25), Color(0.5, 0.42, 0.2)]
	for row in [0.45, 0.95, 1.45]:
		for i in 5:
			_box(Vector3(0.18, 0.32, 0.28), Vector3(-0.5 + i * 0.25, row, 0.05), _m(cols[i % cols.size()]))

func _bed() -> void:
	_box(Vector3(1.0, 0.4, 1.8), Vector3(0, 0.2, 0), _m(DARKWOOD))
	_box(Vector3(0.95, 0.18, 1.7), Vector3(0, 0.5, 0), _m(Color(0.85, 0.82, 0.72)))
	_box(Vector3(0.9, 0.12, 0.5), Vector3(0, 0.62, -0.55), _m(CLOTH))

func _m(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m

func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

func _cyl(radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
