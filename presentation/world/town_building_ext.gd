extends Node3D

# 參數化「城鎮建築外觀」。由 building entity 的 decoration 擺在 rect 左上格中心：
#   local 原點 = anchor(rect 左上)格中心；footprint 格 (dx,dy) 中心在 local (dx*2, 0, dy*2)，每格 2.0。
# 依 footprint 圍一圈石牆、蓋平頂、在 facing 那面的 door 格留門洞(含門楣)、掛一塊招牌。
# 各店只需在自己的 .tscn 設參數（w/h/door_dx/door_dy/facing + 屋頂/招牌色），不必寫 3D 程式。

@export var w: int = 2
@export var h: int = 2
@export var door_dx: int = 0          # 門格在 footprint 內的 x 偏移（0..w-1）
@export var door_dy: int = 0          # 門格在 footprint 內的 y 偏移（0..h-1）
@export var facing: String = "S"      # 門朝外的方向 N/E/S/W
@export var roof_color: Color = Color(0.40, 0.20, 0.14)
@export var sign_color: Color = Color(0.72, 0.52, 0.22)
@export var wall_height: float = 2.6

const STONE_MAT := "res://content/materials/castle_wall_slates/castle_wall_slates.tres"
const WALL_T := 0.25
const DOOR_HALF := 0.7
const DOOR_HEIGHT := 2.0

func _ready() -> void:
	var stone: Material = load(STONE_MAT)
	if stone == null:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.55, 0.52, 0.48)
		stone = sm
	var minx := -1.0
	var maxx := 2.0 * w - 1.0
	var minz := -1.0
	var maxz := 2.0 * h - 1.0
	var cx := (minx + maxx) * 0.5
	var cz := (minz + maxz) * 0.5
	var door_x := door_dx * 2.0
	var door_z := door_dy * 2.0
	# 四面牆：門那一面在 door 格留門洞
	_wall_x(minx, maxx, minz, facing == "N", door_x, stone)   # 北牆
	_wall_x(minx, maxx, maxz, facing == "S", door_x, stone)   # 南牆
	_wall_z(minz, maxz, minx, facing == "W", door_z, stone)   # 西牆
	_wall_z(minz, maxz, maxx, facing == "E", door_z, stone)   # 東牆
	# 平頂（微簷）
	_box(Vector3(2.0 * w + 0.4, 0.3, 2.0 * h + 0.4), Vector3(cx, wall_height + 0.15, cz), _mat(roof_color))
	_spawn_sign(door_x, door_z)

# 沿 X 的牆（固定 z）；has_gap 時在 gap_x 留門洞 + 門楣。
func _wall_x(x0: float, x1: float, z: float, has_gap: bool, gap_x: float, mat: Material) -> void:
	if has_gap:
		_seg_x(x0, gap_x - DOOR_HALF, z, mat)
		_seg_x(gap_x + DOOR_HALF, x1, z, mat)
		_box(Vector3(2.0 * DOOR_HALF, wall_height - DOOR_HEIGHT, WALL_T),
			Vector3(gap_x, DOOR_HEIGHT + (wall_height - DOOR_HEIGHT) * 0.5, z), mat)
	else:
		_seg_x(x0, x1, z, mat)

func _wall_z(z0: float, z1: float, x: float, has_gap: bool, gap_z: float, mat: Material) -> void:
	if has_gap:
		_seg_z(z0, gap_z - DOOR_HALF, x, mat)
		_seg_z(gap_z + DOOR_HALF, z1, x, mat)
		_box(Vector3(WALL_T, wall_height - DOOR_HEIGHT, 2.0 * DOOR_HALF),
			Vector3(x, DOOR_HEIGHT + (wall_height - DOOR_HEIGHT) * 0.5, gap_z), mat)
	else:
		_seg_z(z0, z1, x, mat)

func _seg_x(x0: float, x1: float, z: float, mat: Material) -> void:
	var length := x1 - x0
	if length <= 0.05:
		return
	_box(Vector3(length, wall_height, WALL_T), Vector3((x0 + x1) * 0.5, wall_height * 0.5, z), mat)

func _seg_z(z0: float, z1: float, x: float, mat: Material) -> void:
	var length := z1 - z0
	if length <= 0.05:
		return
	_box(Vector3(WALL_T, wall_height, length), Vector3(x, wall_height * 0.5, (z0 + z1) * 0.5), mat)

func _spawn_sign(door_x: float, door_z: float) -> void:
	var mat := _mat(sign_color)
	var y := DOOR_HEIGHT + 0.15
	match facing:
		"S": _box(Vector3(1.2, 0.55, 0.08), Vector3(door_x, y, 2.0 * h - 1.0 + 0.35), mat)
		"N": _box(Vector3(1.2, 0.55, 0.08), Vector3(door_x, y, -1.0 - 0.35), mat)
		"E": _box(Vector3(0.08, 0.55, 1.2), Vector3(2.0 * w - 1.0 + 0.35, y, door_z), mat)
		"W": _box(Vector3(0.08, 0.55, 1.2), Vector3(-1.0 - 0.35, y, door_z), mat)

func _mat(color: Color) -> Material:
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
