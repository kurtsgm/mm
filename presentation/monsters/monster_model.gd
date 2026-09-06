class_name MonsterModel
extends Node3D

# Shared contract for real 3D monsters: foot origin, +Z forward, 2-unit height.
# Animate joint transforms inside the model; world placement remains owned by the layer.
const HEIGHT := 2.0
const ATTACK_DURATION := 0.58
const HIT_DURATION := 0.32

var phase := 0.0
var animation := "idle"
var _elapsed := 0.0
var _clock := 0.0
var _walk_remaining := 0.0
var _walk_weight := 0.0
var _rest: Dictionary = {}
var _hit_material: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []

@onready var _body: Node3D = $Body
@onready var _head: Node3D = $Body/Head
@onready var _right_arm: Node3D = $Body/RightArm
@onready var _left_arm: Node3D = $Body/LeftArm
@onready var _right_forearm: Node3D = $Body/RightArm/Forearm
@onready var _left_forearm: Node3D = $Body/LeftArm/Forearm
@onready var _right_leg: Node3D = $RightLeg
@onready var _left_leg: Node3D = $LeftLeg

func _ready() -> void:
	for joint in [_body, _head, _right_arm, _left_arm, _right_forearm, _left_forearm, _right_leg, _left_leg]:
		_rest[joint] = joint.transform
	for node in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node)
	_hit_material = StandardMaterial3D.new()
	_hit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_material.albedo_color = Color(1.0, 0.16, 0.06, 0.28)
	_hit_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

func walk_for(duration: float) -> void:
	_walk_remaining = duration

func play_attack() -> void:
	# Damage reactions take priority when both events resolve in the same combat tick.
	if animation == "hit":
		return
	animation = "attack"
	_elapsed = 0.0

func play_hit() -> void:
	animation = "hit"
	_elapsed = 0.0
	for mesh in _meshes:
		mesh.material_overlay = _hit_material

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	_elapsed += delta
	_walk_remaining = maxf(0.0, _walk_remaining - delta)
	_walk_weight = move_toward(_walk_weight, 1.0 if _walk_remaining > 0.0 else 0.0, delta * 10.0)
	if (animation == "attack" and _elapsed >= ATTACK_DURATION) or (animation == "hit" and _elapsed >= HIT_DURATION):
		animation = "idle"
		for mesh in _meshes:
			mesh.material_overlay = null
	for joint in _rest:
		joint.transform = _rest[joint]
	var breath := sin(_clock * TAU / 2.6 + phase)
	_body.position.y += breath * 0.008
	_body.rotation.x = -0.04 + breath * 0.012
	_head.rotation.y = sin(_clock * 0.8 + phase) * 0.045
	_right_arm.rotation.z = -0.08 + breath * 0.018
	_left_arm.rotation.z = 0.08 - breath * 0.018
	_right_forearm.rotation.x = -0.12
	_left_forearm.rotation.x = -0.20
	if _walk_weight > 0.0:
		var step := sin(_clock * 18.0 + phase) * _walk_weight
		_right_leg.rotation.x = step * 0.32
		_left_leg.rotation.x = -step * 0.32
		# Lift the advancing foot so the bent legs do not swing through the floor.
		_right_leg.position.y += maxf(0.0, -step) * 0.07
		_left_leg.position.y += maxf(0.0, step) * 0.07
		_right_arm.rotation.x = -step * 0.16
		_left_arm.rotation.x = step * 0.16
		_body.position.y += absf(step) * 0.018
	if animation == "attack":
		var t := _elapsed / ATTACK_DURATION
		# Wind up, cut down/across, then recover with the feet planted.
		var wind := sin(clampf(t / 0.32, 0.0, 1.0) * PI / 2.0)
		var cut := smoothstep(0.30, 0.60, t)
		var recover := 1.0 - smoothstep(0.66, 1.0, t)
		_right_arm.rotation.x += (-1.7 * wind + 2.7 * cut) * recover
		_right_arm.rotation.z += (0.40 * wind - 0.95 * cut) * recover
		_right_forearm.rotation.x -= 0.55 * wind * (1.0 - cut) * recover
		_body.rotation.y = (0.30 * wind - 0.58 * cut) * recover
		_body.rotation.x += cut * recover * 0.15
		_body.position.z += sin(t * PI) * 0.19
		_left_arm.rotation.x -= sin(t * PI) * 0.38
	elif animation == "hit":
		var t := _elapsed / HIT_DURATION
		var recoil := sin(t * PI)
		_body.rotation.x -= recoil * 0.19
		_body.rotation.z = sin(t * TAU * 2.0) * (1.0 - t) * 0.06
		_body.position.z -= recoil * 0.12
		_head.rotation.x -= recoil * 0.14
		_hit_material.albedo_color.a = (1.0 - t) * 0.28
