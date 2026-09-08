extends SceneTree

# Rendered standalone asset benchmark, not a whole-game performance claim.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1280,720)
	var stage:=Node3D.new()
	root.add_child(stage)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("162027")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("b9cbcf")
	env.environment.ambient_light_energy=0.6
	stage.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-25,0)
	light.light_energy=1.2
	light.shadow_enabled=true
	stage.add_child(light)
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.position=Vector3(0,2.3,5.4)
	camera.look_at(Vector3(0,0.65,0))
	camera.current=true
	var report: Dictionary={"engine":Engine.get_version_info().string,"renderer":"Compatibility","resolution":[1280,720],"samples":[]}
	for count in [2,16]:
		var models: Array[Node3D]=[]
		for i in count:
			var model:=MonsterModelCatalog.instantiate("dream_wisp")
			stage.add_child(model)
			model.position=Vector3((i%4-1.5)*1.12,0,(i/4 as int-1.5)*0.85)
			models.append(model)
		for frame in 60: await process_frame
		var durations: Array[float]=[]
		var start:=Time.get_ticks_usec()
		var previous:=start
		for frame in 180:
			await process_frame
			var now:=Time.get_ticks_usec()
			durations.append((now-previous)/1000.0)
			previous=now
		durations.sort()
		var sample: Dictionary={"instances":count,"median_frame_ms":durations[90],"p95_frame_ms":durations[171],"mean_fps":180000000.0/(previous-start),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
		report.samples.append(sample)
		print(sample)
		for model in models: model.queue_free()
		await process_frame
	var args:=OS.get_cmdline_user_args()
	var output:="/tmp/dream-wisp-benchmark.json" if args.is_empty() else args[0]
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	stage.queue_free()
	quit()
