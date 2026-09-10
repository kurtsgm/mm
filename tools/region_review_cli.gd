extends SceneTree

var _job: Dictionary
var _maps: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Expected one job JSON path")
		quit(2)
		return
	_job = ContentRegistry.read_json(args[0])
	var region := ContentRegistry.read_json(_job.get("region", ""))
	if region.is_empty():
		printerr("Missing region/job")
		quit(2)
		return
	_maps = MapLint.load_maps()
	var report := {"errors": ContentLint.run(), "scenarios": {}, "maps": {}, "manual_checks": region.get("manual_checks", [])}
	var quests := QuestLint.run()
	report["errors"].append_array(quests["errors"])
	report["warnings"] = quests["warnings"]
	report["errors"].append_array(MapLint.run(_maps))
	for route in region["routes"]:
		var from := _entry(route["from"])
		var to := _entry(route["to"])
		if from.is_empty() or to.is_empty() or MapLint.path(_maps, from, to).is_empty():
			report["errors"].append("region route unavailable: %s" % route)
		elif route.get("return_required", true) and MapLint.path(_maps, to, from).is_empty():
			report["errors"].append("region return route unavailable: %s" % route)
	for id in region["content"]["maps"]:
		if not _maps.has(id):
			continue
		var map: MapData = _maps[id]
		if not ThemeCatalog.has_theme(map.theme_id):
			report["errors"].append("map/%s: missing theme %s" % [id, map.theme_id])
		var track := AudioCatalog.track_entry(map.bgm)
		if track.is_empty() or not FileAccess.file_exists(track.get("path", "")):
			report["errors"].append("map/%s: missing BGM %s" % [id, map.bgm])
		elif "placeholder" in String(track.get("path", "")):
			report["warnings"].append("map/%s: placeholder BGM %s" % [id, map.bgm])
		var tiles := []
		for y in map.height:
			var row := ""
			for x in map.width:
				row += "." if MapLint.walkable(map, Vector2i(x, y)) else "#"
			tiles.append(row)
		var markers := []
		for p in map.links:
			markers.append({"pos": [p.x, p.y], "label": "P", "detail": str(map.links[p])})
		for group in [[map.scenes, "S"], [map.quest_givers, "N"], [map.objects, "C"]]:
			for entity in group[0]:
				markers.append({"pos": [entity["pos"].x, entity["pos"].y], "label": group[1], "detail": str(entity)})
		for p in map.encounters:
			markers.append({"pos": [p.x, p.y], "label": "M", "detail": map.encounters[p]})
		report["maps"][id] = {"name": map.display_name, "grid": tiles, "markers": markers, "neighbors": map.neighbors}
	for name in region["scenarios"]:
		var gs = _new_state()
		var flow := RegionFlow.new(_maps, gs)
		var scenario: Dictionary = region["scenarios"][name]
		var ok := flow.begin(scenario["start"])
		if ok:
			for step in scenario["steps"]:
				if not flow.step(step):
					break
		report["scenarios"][name] = {"errors": flow.errors, "steps": flow.trace.size(), "walked_cells": flow.walked_cells}
		for error in flow.errors:
			report["errors"].append("scenario/%s step %d: %s" % [name, flow.trace.size(), error])
		gs.free()
	var file := FileAccess.open(_job["report"], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	if not report["errors"].is_empty():
		for error in report["errors"]:
			printerr(error)
		quit(1)
		return
	if _job["mode"] == "check":
		quit(0)
		return
	var checkpoint: Dictionary = region["previews"][_job["case"]]
	var gs = _new_state()
	var flow := RegionFlow.new(_maps, gs)
	if checkpoint.has("scenario"):
		var scenario: Dictionary = region["scenarios"][checkpoint["scenario"]]
		flow.begin(scenario["start"])
		for i in int(checkpoint["after_steps"]):
			if not flow.step(scenario["steps"][i]):
				printerr("Checkpoint replay failed: ", flow.errors)
				gs.free()
				quit(1)
				return
	if not flow.begin(checkpoint["start"]):
		printerr(flow.errors)
		gs.free()
		quit(1)
		return
	var saver = root.get_node("SaveSystem")
	var snapshot: SaveData = saver.capture_from(gs)
	# Snapshot owns resources after the temporary state is freed; no save slot is written.
	gs.free()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main = load("res://presentation/world/main.tscn").instantiate()
	root.add_child(main)
	saver.apply(snapshot)
	root.get_node("GameState").message_log.push("區域預覽：%s / %s" % [region["title"], _job["case"]])
	print("REGION_PREVIEW_READY: %s/%s" % [region["id"], _job["case"]])
	if checkpoint.get("walk_forward", false):
		var move := InputEventAction.new()
		move.action = "move_forward"
		move.pressed = true
		main._player._unhandled_input(move)
		var deadline := Time.get_ticks_msec() + 10000
		while not main._cutscene_player._dialogue_overlay.is_open() and Time.get_ticks_msec() < deadline:
			await process_frame
		if not main._cutscene_player._dialogue_overlay.is_open():
			printerr("Forward step did not open the expected cutscene dialogue")
			quit(1)
			return
	if _job["mode"] == "capture":
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_webp(_job["capture"])
		if result != OK:
			printerr("Capture failed: ", result)
		if checkpoint.get("walk_forward", false):
			var overlay: DialogueOverlay = main._cutscene_player._dialogue_overlay
			var locked: bool = not main._player._enabled
			# Complete through the real overlay callback so capture does not quit during await.
			for i in 20:
				if not overlay.is_open():
					break
				var key := InputEventKey.new()
				key.keycode = KEY_1
				key.pressed = true
				overlay._unhandled_input(key)
				await process_frame
			var deadline := Time.get_ticks_msec() + 10000
			while main._cutscene_player.is_playing() and Time.get_ticks_msec() < deadline:
				await process_frame
			var live = root.get_node("GameState")
			var completed: bool = locked and main._player._enabled and DialogueCondition.passes(checkpoint.get("expect_after"), live) and live.is_scene_triggered(live.current_map_id, live.player_pos)
			report["rendered_scene_check"] = {"input_locked_during_dialogue": locked, "completed_and_input_restored": completed}
			file = FileAccess.open(_job["report"], FileAccess.WRITE)
			file.store_string(JSON.stringify(report, "  "))
			file.close()
			if not completed:
				printerr("Rendered scene did not finish with expected state and input ownership")
				result = FAILED
		main.queue_free()
		await process_frame
		quit(0 if result == OK else 1)

func _new_state():
	var gs = load("res://autoload/game_state.gd").new()
	root.add_child(gs)
	return gs

func _entry(spec: Dictionary) -> Dictionary:
	var map: MapData = _maps.get(spec["map"])
	if map == null or not map.has_entry(spec.get("entry", "start")):
		return {}
	return {"map": map.map_id, "pos": map.get_entry(spec.get("entry", "start"))["pos"]}
