extends Node3D

# 「示意城鎮」prop：用 Kenney Retro Fantasy kit 的零件組一座小城堡城門（城門 + 兩側塔 + 中央 keep）。
# 自我組裝：實例化進場景樹時於 _ready 載入零件、依材質名補回 kit 貼圖、依擺位拼出。
# kit 的 GLB 未嵌貼圖，材質名(planks/stones/bricks/roof…)對應 kit 的 Textures（見 OBJ .mtl）。

const KIT := "res://content/models/kenney_retro_fantasy/"
const TEX := "res://content/models/kenney_retro_fantasy/textures/"
const MAT_TEX := {
	"planks": "planks",
	"stones": "cobblestone",
	"bricks": "cobblestoneAlternative",
	"roof": "roof",
}

# [piece, Vector3 pos, yaw_deg]
const LAYOUT := [
	["wall-fortified-gate", Vector3(0, 0, 0), 0.0],
	["tower", Vector3(-1, 0, 0), 0.0],
	["tower-top", Vector3(-1, 1, 0), 0.0],
	["tower", Vector3(1, 0, 0), 0.0],
	["tower-top", Vector3(1, 1, 0), 0.0],
	["tower", Vector3(0, 0, -1.4), 0.0],
	["roof", Vector3(0, 1, -1.4), 0.0],
]

func _ready() -> void:
	for entry in LAYOUT:
		_spawn(entry[0], entry[1], entry[2])

func _spawn(piece: String, pos: Vector3, yaw_deg: float) -> void:
	var scene: PackedScene = load(KIT + piece + ".glb")
	if scene == null:
		return
	var inst: Node3D = scene.instantiate()
	add_child(inst)
	inst.position = pos
	inst.rotation.y = deg_to_rad(yaw_deg)
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			var mat_name := src.resource_name if src else ""
			var mat := StandardMaterial3D.new()
			if MAT_TEX.has(mat_name):
				mat.albedo_texture = load(TEX + MAT_TEX[mat_name] + ".png")
			else:
				mat.albedo_color = Color(0.6, 0.6, 0.62)
			mi.set_surface_override_material(s, mat)
