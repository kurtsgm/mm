extends SceneTree
## Internal worker. Public entry point: python3 tools/monster_pipeline.py --help
const Validator = preload("res://tools/monster_asset_validator.gd")
const Preview = preload("res://presentation/monsters/goblin_preview.gd")

var job: Dictionary
var _rendered_frames := 0

func _count_rendered_frame() -> void:
	_rendered_frames += 1

func _initialize() -> void:
	call_deferred("_run")

func _save(filename: String, value: Variant) -> bool:
	var file := FileAccess.open(job.output.path_join(filename), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write report: " + filename)
		return false
	file.store_string(JSON.stringify(value, "\t"))
	return true

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--job":
		push_error("Expected --job <absolute JSON path>")
		quit(2)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not parsed is Dictionary:
		quit(2)
		return
	job = parsed
	if job.mode == "validate":
		_validate()
		return
	if DisplayServer.get_name() == "headless":
		push_error("Capture and benchmark require a real rendering window")
		quit(2)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(job.width, job.height)
	root.mesh_lod_threshold = 0.0 if job.no_lod else 1.0
	if job.mode == "capture":
		await _capture()
	elif job.mode == "benchmark":
		await _benchmark()
	elif job.mode == "preview":
		var preview := Preview.new()
		preview.configure_review(job.monsters[0])
		root.add_child(preview)
	else:
		quit(2)

func _validate() -> void:
	var reports: Array = []
	var failed := false
	if job.get("check_catalog_coverage", false):
		var covered: Array = job.monsters.map(func(spec): return spec.id)
		for id in MonsterModelCatalog._MODELS:
			if id not in covered:
				reports.append({"id": id, "errors": ["registered model missing from manifest"], "warnings": [], "metrics": {}})
				failed = true
	for spec in job.monsters:
		var packed = load(spec.scene) if ResourceLoader.exists(spec.scene) else null
		var model = packed.instantiate() if packed is PackedScene else null
		if not model is MonsterModel:
			if model != null:
				model.free()
			reports.append({"id": spec.id, "errors": ["missing scene or MonsterModel driver"], "warnings": [], "metrics": {}})
			failed = true
			continue
		root.add_child(model)
		var report := Validator.inspect(model, spec, job.budgets)
		reports.append(report)
		failed = failed or not report.errors.is_empty()
		print("VALIDATE %s: %d errors, %d budget warnings" % [spec.id, report.errors.size(), report.warnings.size()])
		model.free()
	if not _save("validation.json", reports):
		failed = true
	quit(1 if failed else 0)

func _environment() -> Dictionary:
	return {
		"engine": Engine.get_version_info().string,
		"os": OS.get_name(), "cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(),
		"resolution": [root.size.x, root.size.y],
		"lod_threshold": root.mesh_lod_threshold,
		"msaa": root.msaa_3d,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
	}

func _capture() -> void:
	var shots := [
		{"name": "front", "clip": "idle", "fraction": 0.0, "yaw": 0.0},
		{"name": "side", "clip": "idle", "fraction": 0.0, "yaw": PI / 2},
		{"name": "back", "clip": "idle", "fraction": 0.0, "yaw": PI},
		{"name": "walk", "clip": "walk", "fraction": 0.32, "yaw": 0.3},
		{"name": "attack", "clip": "attack", "fraction": 0.40, "yaw": 0.3},
		{"name": "hit", "clip": "hit", "fraction": 0.40, "yaw": 0.3},
		{"name": "rig", "clip": "attack", "fraction": 0.40, "yaw": 0.3, "bones": true},
	]
	var captures: Array = []
	for spec in job.monsters:
		var stage := Preview.new()
		stage.configure_review(spec)
		root.add_child(stage)
		stage.set_process_unhandled_input(false)
		for shot in shots:
			stage.set_review_pose(shot.clip, shot.fraction, shot.yaw, shot.get("bones", false))
			# Let skinning, materials and the render thread settle before reading pixels.
			for frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var relative := "%s-%s.webp" % [spec.id, shot.name]
			var picture := root.get_texture().get_image()
			if picture == null or picture.is_empty() or picture.save_webp(job.output.path_join(relative), true, 0.85) != OK:
				push_error("Capture failed: " + relative)
				quit(1)
				return
			captures.append({"id": spec.id, "file": relative, "pose": shot, "camera_target": spec.preview.target, "camera_distance": spec.preview.distance, "camera_pitch": spec.preview.pitch})
		stage.queue_free()
		await process_frame
		print("CAPTURE %s: %d WebP images" % [spec.id, shots.size()])
	quit(0 if _save("captures.json", {"environment": _environment(), "lighting": "shared warm studio", "captures": captures}) else 1)

func _benchmark() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.msaa_3d = Viewport.MSAA_DISABLED
	# Window occlusion may stop automatic drawing while SceneTree keeps ticking.
	# Explicitly render an always-updated offscreen viewport; never sample stale
	# Performance monitors or treat process_frame alone as proof of rendering.
	RenderingServer.render_loop_enabled = false
	RenderingServer.frame_post_draw.connect(_count_rendered_frame)
	var viewport := SubViewport.new()
	viewport.size = root.size
	viewport.own_world_3d = true
	viewport.mesh_lod_threshold = root.mesh_lod_threshold
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.texture = viewport.get_texture()
	root.add_child(display)
	var groups: Array = []
	for spec in job.monsters:
		groups.append({"name": spec.id, "members": [spec]})
	if job.monsters.size() > 1:
		groups.append({"name": "mixed", "members": job.monsters})
	var report := {"scope": "standalone rendered assets; not whole-game FPS", "render_policy": "explicit force_draw + always-updated SubViewport", "environment": _environment(), "warmup_frames": job.warmup, "sample_frames": job.frames, "animation": "idle", "shadows": true, "samples": []}
	for group in groups:
		for requested_count in job.counts:
			var count := int(requested_count)
			if count < group.members.size():
				continue # A mixed sample must include every selected species.
			var stage := Node3D.new()
			viewport.add_child(stage)
			var environment := WorldEnvironment.new()
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color("162027")
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_energy = 0.6
			stage.add_child(environment)
			var light := DirectionalLight3D.new()
			light.rotation_degrees = Vector3(-35, -25, 0)
			light.shadow_enabled = true
			stage.add_child(light)
			var columns := ceili(sqrt(count))
			var rows := ceili(float(count) / columns)
			var composition := {}
			# Fixed spacing/camera policy across species; fit the entire grid into view.
			for i in count:
				var spec: Dictionary = group.members[i % group.members.size()]
				var model := MonsterModelCatalog.instantiate(spec.id)
				stage.add_child(model)
				model.position = Vector3((i % columns - (columns - 1) * 0.5) * 3.0, 0, (floori(float(i) / columns) - (rows - 1) * 0.5) * 3.0)
				model.phase = float(i) * 0.173
				composition[spec.id] = composition.get(spec.id, 0) + 1
			var camera := Camera3D.new()
			camera.fov = 37.0
			stage.add_child(camera)
			camera.position = Vector3(0, 3.0 + rows * 0.9, maxf(6.0, columns * 3.0 / float(job.width) * float(job.height) + rows * 2.6))
			camera.look_at(Vector3(0, 0.9, 0))
			camera.current = true
			for frame in job.warmup:
				await process_frame
				RenderingServer.force_draw(true)
			var durations: Array[float] = []
			var calls := 0.0
			var primitives := 0.0
			var start := Time.get_ticks_usec()
			var previous := start
			var rendered_start := _rendered_frames
			for frame in job.frames:
				await process_frame
				RenderingServer.force_draw(true)
				var now := Time.get_ticks_usec()
				durations.append((now - previous) / 1000.0)
				previous = now
				calls += RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
				primitives += RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			var raw_frame_ms := durations.duplicate()
			durations.sort()
			var sample := {"group": group.name, "instances": count, "composition": composition, "median_frame_ms": durations[durations.size() / 2], "p95_frame_ms": durations[ceili(durations.size() * 0.95) - 1], "mean_fps": job.frames * 1000000.0 / (previous - start), "mean_draw_calls": calls / job.frames, "mean_primitives": primitives / job.frames, "camera_position": [camera.position.x, camera.position.y, camera.position.z], "warnings": []}
			sample.frame_ms = raw_frame_ms
			sample.camera_fov = camera.fov
			sample.rendered_frames = _rendered_frames - rendered_start
			if sample.rendered_frames < int(job.frames) or calls <= 0 or primitives <= 0:
				push_error("Benchmark did not render the requested workload")
				quit(1)
				return
			var workload_image := "benchmark-%s-%d.webp" % [group.name, count]
			if viewport.get_texture().get_image().save_webp(job.output.path_join(workload_image), true, 0.85) != OK:
				push_error("Cannot save benchmark workload image")
				quit(1)
				return
			sample.workload_image = workload_image
			if count == int(job.budgets.benchmark_instances) and sample.p95_frame_ms > job.budgets.benchmark_p95_ms:
				sample.warnings.append("P95 exceeds draft %s ms budget at %d instances" % [job.budgets.benchmark_p95_ms, count])
			report.samples.append(sample)
			print("BENCHMARK %s x%d: P95 %.2f ms" % [group.name, count, sample.p95_frame_ms])
			stage.queue_free()
			await process_frame
	quit(0 if _save("benchmark.json", report) else 1)
