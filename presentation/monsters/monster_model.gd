class_name MonsterModel
extends Node3D

# +Z forward, sole origin. Shared baked meshes/animations, per-instance pose and hit overlay.
const HEIGHT := 2.0
const ATTACK_DURATION := 0.58
const HIT_DURATION := 0.32

var phase := 0.0
var animation := "idle"
var _elapsed := 0.0
var _clock := 0.0
var _walk_remaining := 0.0
var _hit_material: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _clip := ""

@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for node in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node)
	_hit_material = StandardMaterial3D.new()
	_hit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_material.albedo_color = Color(1.0, 0.16, 0.06, 0.28)
	_hit_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

func walk_for(duration: float) -> void:
	_walk_remaining = maxf(0.0, duration)

func play_attack() -> void:
	if animation == "hit":
		return
	animation = "attack"
	_elapsed = 0.0
	_clip = ""

func play_hit() -> void:
	animation = "hit"
	_elapsed = 0.0
	_clip = ""
	_hit_material.albedo_color.a = 0.28
	for mesh in _meshes:
		mesh.material_overlay = _hit_material

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	_elapsed += delta
	_walk_remaining = maxf(0.0, _walk_remaining - delta)
	if (animation == "attack" and _elapsed >= ATTACK_DURATION) or (animation == "hit" and _elapsed >= HIT_DURATION):
		animation = "idle"
		for mesh in _meshes:
			mesh.material_overlay = null
	var desired := animation
	if animation == "idle" and _walk_remaining > 0.0:
		desired = "walk"
	if desired != _clip:
		animation_player.play(desired, 0.10 if not _clip.is_empty() else 0.0)
		_clip = desired
		if desired in ["idle", "walk"]:
			animation_player.seek(fposmod(_clock + phase, animation_player.get_animation(desired).length), true)
		else:
			animation_player.seek(_elapsed, true)
		animation_player.advance(0.0)
	else:
		animation_player.advance(delta)
	if animation == "hit":
		_hit_material.albedo_color.a = (1.0 - _elapsed / HIT_DURATION) * 0.28
