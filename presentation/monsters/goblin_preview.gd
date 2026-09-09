extends Node3D

# Standalone review scene: ./run.sh res://presentation/monsters/goblin_preview.tscn
@export var monster_id := "goblin"
@export var display_name := "獵荒哥布林"
@export var species_label := "GOBLIN"
@export var attack_label := "揮砍"
@export var camera_target := Vector3(0, 1.0, 0)
@export var initial_distance := 4.6
@export var initial_pitch := 0.10
@export var soft_studio_lighting := false

var _model: MonsterModel
var _camera: Camera3D
var _yaw := 0.30
var _pitch := 0.10
var _distance := 4.6
var _rotate := false
var _walking := false
var _status: Label
var _bones: MeshInstance3D
var _show_bones := false
var _rest_pose := false

func configure_review(spec: Dictionary) -> void:
	monster_id = spec.id
	display_name = spec.display_name
	species_label = monster_id.to_upper().replace("_", " ")
	attack_label = spec.preview.attack_label
	var target: Array = spec.preview.target
	camera_target = Vector3(target[0], target[1], target[2])
	initial_distance = spec.preview.distance
	initial_pitch = spec.preview.pitch
	# Every species uses the same lighting for production comparisons.
	soft_studio_lighting = true

func set_review_pose(clip: String, fraction: float, yaw: float, bones: bool = false) -> void:
	set_process(false)
	_model.set_process(false)
	_model.animation_player.stop()
	_model.skeleton.reset_bone_poses()
	_model.animation_player.play(clip)
	_model.animation_player.seek(_model.animation_player.get_animation(clip).length * fraction, true)
	_model.animation_player.advance(0)
	_yaw = yaw
	_update_camera()
	_bones.visible = bones
	if bones:
		_draw_bones()
	_status.text = "%s · %d%%" % [clip, roundi(fraction * 100)]

func _ready() -> void:
	_distance = initial_distance
	_pitch = initial_pitch
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("11191d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a6bcc5")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	if soft_studio_lighting:
		for spec in [[Vector3(-30,-25,0),Color("fff0dc"),0.50],[Vector3(-15,135,0),Color("b6c9e5"),0.18],[Vector3(-25,180,0),Color("ddd2ef"),0.25]]:
			var light:=DirectionalLight3D.new()
			light.rotation_degrees=spec[0]
			light.light_color=spec[1]
			light.light_energy=spec[2]
			light.shadow_enabled=stage_key_shadow(spec[2])
			light.shadow_bias=0.08
			light.shadow_normal_bias=1.0
			light.directional_shadow_max_distance=8.0
			add_child(light)
	else:
		_light(Vector3(-3, 4, 4), Color("ffdaa1"), 2.0, 8.0)
		_light(Vector3(3, 2.5, 1), Color("aecddd"), 0.9, 7.0)
		_light(Vector3(0.5, 3, -3), Color("bcdfc4"), 2.0, 7.0)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 1.35
	floor_mesh.bottom_radius = 1.43
	floor_mesh.height = 0.12
	floor_mesh.radial_segments = 96
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("293134")
	floor_mat.roughness = 0.88
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = floor_mat
	floor_node.position.y = -0.06
	add_child(floor_node)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.29
	ring.outer_radius = 1.30
	ring.rings = 96
	ring.ring_segments = 8
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("ac8b50")
	ring_mat.metallic = 0.7
	ring_node.material_override = ring_mat
	add_child(ring_node)
	_model = MonsterModelCatalog.instantiate(monster_id)
	add_child(_model)
	# Optional side-by-side asset review at each species' actual game scale.
	var args := OS.get_cmdline_user_args()
	var compare := args.find("--compare")
	if compare >= 0 and compare + 1 < args.size() and MonsterModelCatalog.has_model(args[compare + 1]):
		var other := MonsterModelCatalog.instantiate(args[compare + 1])
		add_child(other)
		other.position.x = -0.70
		_model.position.x = 0.70
		camera_target = Vector3(0, 0.9, 0)
		_distance = 5.6
		_pitch = 0.16
	_bones = MeshInstance3D.new()
	_bones.mesh = ImmediateMesh.new()
	var bone_mat := StandardMaterial3D.new()
	bone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bone_mat.no_depth_test = true
	bone_mat.albedo_color = Color("61efd0")
	_bones.material_override = bone_mat
	add_child(_bones)
	_camera = Camera3D.new()
	_camera.fov = 37.0
	add_child(_camera)
	_camera.make_current()
	_update_camera()
	_build_ui()
	_capture_if_requested()

func stage_key_shadow(energy: float) -> bool:
	return energy>0.45 and not "--no-shadows" in OS.get_cmdline_user_args()

func _light(pos: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = not "--no-shadows" in OS.get_cmdline_user_args()
	add_child(light)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var title := Label.new()
	title.text = display_name
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("e1d4b4"))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.anchor_left = 0.05
	title.anchor_top = 0.06
	title.anchor_right = 0.95
	canvas.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "%s  /  SKINNED CHARACTER · %d BONES" % [species_label, _model.skeleton.get_bone_count()]
	subtitle.add_theme_color_override("font_color", Color("a8b4b8"))
	subtitle.anchor_left = 0.05
	subtitle.anchor_top = 0.13
	canvas.add_child(subtitle)
	_status = Label.new()
	_status.anchor_left = 0.05
	_status.anchor_top = 0.21
	_status.add_theme_color_override("font_color", Color("aa956d"))
	canvas.add_child(_status)
	var controls := HBoxContainer.new()
	controls.anchor_left = 0.05
	controls.anchor_right = 0.95
	controls.anchor_top = 0.88
	controls.anchor_bottom = 0.94
	controls.add_theme_constant_override("separation", 12)
	canvas.add_child(controls)
	for spec in [[attack_label+" · Space", _attack], ["受擊 · H", _hit], ["行走 · W", _walk], ["環繞 · R", _orbit], ["骨架 · B", _toggle_bones], ["綁定姿勢 · T", _toggle_rest]]:
		var button := Button.new()
		button.text = spec[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(spec[1])
		controls.add_child(button)
	var hint := Label.new()
	hint.text = "拖曳旋轉視角  ·  滾輪縮放  ·  1 正面 / 2 側面 / 3 背面"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.05
	hint.anchor_right = 0.95
	hint.anchor_top = 0.96
	hint.add_theme_color_override("font_color", Color("8e9a9e"))
	canvas.add_child(hint)

func _process(delta: float) -> void:
	if _rotate:
		_yaw += delta * 0.45
		_update_camera()
	if _show_bones:
		_draw_bones()
	if _walking and not _rest_pose:
		_model.walk_for(0.2)
	_status.text = {"idle": "待機 / 呼吸", "attack": "攻擊 / "+attack_label, "hit": "受擊 / 後仰"}[_model.animation] if not _walking else "行走 / 骨骼蒙皮"
	if _rest_pose:
		_status.text = "綁定姿勢 / %d bones" % _model.skeleton.get_bone_count()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_rotate = false
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.005, -0.12, 0.65)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(initial_distance*0.4, _distance - 0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(7.0, _distance + 0.25)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _attack()
			KEY_H: _hit()
			KEY_W: _walk()
			KEY_R: _orbit()
			KEY_B: _toggle_bones()
			KEY_T: _toggle_rest()
			KEY_1: _yaw = 0.0
			KEY_2: _yaw = PI / 2.0
			KEY_3: _yaw = PI
		_update_camera()

func _update_camera() -> void:
	var target := camera_target
	_camera.position = target + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.look_at(target)

func _attack() -> void:
	_leave_rest()
	_model.play_attack()

func _hit() -> void:
	_leave_rest()
	_model.play_hit()

func _walk() -> void:
	_leave_rest()
	_walking = not _walking

func _orbit() -> void:
	_rotate = not _rotate

func _leave_rest() -> void:
	_rest_pose = false
	_model.set_process(true)

func _toggle_rest() -> void:
	_rest_pose = not _rest_pose
	_model.set_process(not _rest_pose)
	if _rest_pose:
		_model.animation_player.stop()
		_model.skeleton.reset_bone_poses()
		_model._clip = ""

func _toggle_bones() -> void:
	_show_bones = not _show_bones
	_bones.visible = _show_bones

func _draw_bones() -> void:
	var mesh := _bones.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var rig := _model.skeleton
	for i in rig.get_bone_count():
		var parent := rig.get_bone_parent(i)
		if parent < 0:
			continue
		var a := _model.transform * rig.get_bone_global_pose(parent).origin
		var b := _model.transform * rig.get_bone_global_pose(i).origin
		mesh.surface_add_vertex(a)
		mesh.surface_add_vertex(b)
		for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
			mesh.surface_add_vertex(b-axis*0.009)
			mesh.surface_add_vertex(b+axis*0.009)
	mesh.surface_end()

# Optional reproducible render for review; only used when explicitly passed on the command line.
func _capture_if_requested() -> void:
	var args := OS.get_cmdline_user_args()
	if "--no-lod" in args: get_viewport().mesh_lod_threshold=0.0
	var capture := args.find("--capture")
	if capture < 0 or capture + 1 >= args.size():
		return
	var angle := args.find("--yaw")
	if angle >= 0 and angle + 1 < args.size():
		_yaw = float(args[angle + 1])
	var pitch := args.find("--pitch")
	if pitch >= 0 and pitch + 1 < args.size():
		_pitch = float(args[pitch + 1])
	var distance := args.find("--distance")
	if distance >= 0 and distance + 1 < args.size():
		_distance = maxf(0.5, float(args[distance + 1]))
	_update_camera()
	var pose := args.find("--pose")
	if pose >= 0 and pose + 1 < args.size():
		_model.set_process(false)
		_model.animation = args[pose+1] if args[pose+1] != "walk" else "idle"
		_walking = args[pose+1] == "walk"
		_model.animation_player.play(args[pose+1])
		_model.animation_player.seek(0.23, true)
		_model.animation_player.advance(0)
	if "--bones" in args:
		_toggle_bones()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(args[capture + 1])
	print("Preview capture: ", error_string(result))
	get_tree().quit(0 if result == OK else 1)
