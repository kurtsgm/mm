extends Node3D

# 程序化寶箱 placeholder（鏡射 town_oak_ext：.tscn + .gd 自建幾何）。
# @export opened 控制蓋子角度：closed=平蓋、open=掀起。
# 日後可把此 .gd 換成真模型，或直接改 .tscn 的 ext_resource 指向 GLB。

@export var opened: bool = false

const BODY := Vector3(0.9, 0.55, 0.6)
const LID_H := 0.2

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.30, 0.15)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = BODY
	body.mesh = bm
	body.material_override = mat
	body.position = Vector3(0.0, BODY.y / 2.0, 0.0)
	add_child(body)
	# 蓋子掛在後緣樞紐上，open 時向後掀起
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, BODY.y, -BODY.z / 2.0)
	add_child(pivot)
	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(BODY.x, LID_H, BODY.z)
	lid.mesh = lm
	lid.material_override = mat
	lid.position = Vector3(0.0, LID_H / 2.0, BODY.z / 2.0)
	pivot.add_child(lid)
	if opened:
		pivot.rotation.x = deg_to_rad(-110.0)
