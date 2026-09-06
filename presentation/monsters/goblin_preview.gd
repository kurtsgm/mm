extends Node3D

# Standalone review scene: ./run.sh res://presentation/monsters/goblin_preview.tscn
var _model: MonsterModel
var _camera: Camera3D
var _yaw := 0.30
var _pitch := 0.10
var _distance := 4.6
var _rotate := false
var _walking := false
var _status: Label

func _ready() -> void:
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
	_light(Vector3(-3, 4, 4), Color("ffdaa1"), 3.2, 8.0)
	_light(Vector3(3, 2.5, 1), Color("aecddd"), 1.6, 7.0)
	_light(Vector3(0.5, 3, -3), Color("bcdfc4"), 3.6, 7.0)
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
	_model = MonsterModelCatalog.instantiate("goblin")
	add_child(_model)
	_camera = Camera3D.new()
	_camera.fov = 37.0
	add_child(_camera)
	_camera.make_current()
	_update_camera()
	_build_ui()
	_capture_if_requested()

func _light(pos: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = true
	add_child(light)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var title := Label.new()
	title.text = "獵荒哥布林"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("e1d4b4"))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.anchor_left = 0.05
	title.anchor_top = 0.06
	title.anchor_right = 0.95
	canvas.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "GOBLIN  /  3D CREATURE STUDY"
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
	controls.anchor_left = 0.22
	controls.anchor_right = 0.78
	controls.anchor_top = 0.88
	controls.anchor_bottom = 0.94
	controls.add_theme_constant_override("separation", 12)
	canvas.add_child(controls)
	for spec in [["揮砍 · Space", _attack], ["受擊 · H", _hit], ["行走 · W", _walk], ["環繞 · R", _orbit]]:
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
	if _walking:
		_model.walk_for(0.2)
	_status.text = {"idle": "待機 / 呼吸", "attack": "攻擊 / 揮砍", "hit": "受擊 / 後仰"}[_model.animation] if not _walking else "行走 / 關節動畫"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_rotate = false
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.005, -0.12, 0.65)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(2.8, _distance - 0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(7.0, _distance + 0.25)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _attack()
			KEY_H: _hit()
			KEY_W: _walk()
			KEY_R: _orbit()
			KEY_1: _yaw = 0.0
			KEY_2: _yaw = PI / 2.0
			KEY_3: _yaw = PI
		_update_camera()

func _update_camera() -> void:
	var target := Vector3(0, 1.0, 0)
	_camera.position = target + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.look_at(target)

func _attack() -> void:
	_model.play_attack()

func _hit() -> void:
	_model.play_hit()

func _walk() -> void:
	_walking = not _walking

func _orbit() -> void:
	_rotate = not _rotate

# Optional reproducible render for review; only used when explicitly passed on the command line.
func _capture_if_requested() -> void:
	var args := OS.get_cmdline_user_args()
	var capture := args.find("--capture")
	if capture < 0 or capture + 1 >= args.size():
		return
	var angle := args.find("--yaw")
	if angle >= 0 and angle + 1 < args.size():
		_yaw = float(args[angle + 1])
		_update_camera()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(args[capture + 1])
	print("Preview capture: ", error_string(result))
	get_tree().quit(0 if result == OK else 1)
