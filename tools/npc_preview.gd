extends SceneTree

# 真實地圖＋正式主場景的 NPC sample；不讀寫任何存檔槽。
# godot --path . --script res://tools/npc_preview.gd -- [--npc=margo] [--map=town_oak]
# 加 --capture=res://build/npc-margo.webp 可截圖後退出；--verify-dialogue 驗證空白鍵交談。
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var npc_id := "margo"
	var map_id := "town_oak"
	var capture := ""
	var verify := false
	var distance := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--npc="):
			npc_id = arg.trim_prefix("--npc=")
		elif arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
		elif arg.begins_with("--capture="):
			capture = arg.trim_prefix("--capture=")
		elif arg == "--verify-dialogue":
			verify = true
		elif arg.begins_with("--distance="):
			distance = arg.trim_prefix("--distance=").to_int()
		else:
			_fail("Unknown argument: " + arg)
			return
	if distance < 1 or distance > 4 or (verify and distance != 1):
		_fail("Distance must be 1–4 cells; dialogue verification requires distance 1")
		return
	if not capture.is_empty() and DisplayServer.get_name() == "headless":
		_fail("Capture requires a rendering window; omit --headless")
		return
	var manager = root.get_node("MapManager")
	var map: MapData = manager.peek_map(map_id)
	if map == null:
		_fail("Unknown map: " + map_id)
		return
	var target: Dictionary = {}
	for q in map.quest_givers:
		if q.get("sprite", "") == npc_id:
			target = q
			break
	if target.is_empty() or NpcSpriteCatalog.presentation_for(npc_id).is_empty():
		_fail("NPC must exist on map and in NpcSpriteCatalog: " + npc_id)
		return
	var grid := WorldGrid.new(map, Callable(manager, "peek_map"))
	var facing := -1
	var pos := Vector2i.ZERO
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i in 4:
		var candidate: Vector2i = target["pos"] - directions[i] * distance
		var clear := true
		for step in range(1, distance + 1):
			var cell: Vector2i = target["pos"] - directions[i] * step
			if not grid.is_walkable(cell) or not grid.occupant_at(cell).is_empty():
				clear = false
		if clear:
			pos = candidate
			facing = i
			break
	if facing == -1:
		_fail("No clear viewing path for " + npc_id)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 800)
	var main = load("res://presentation/world/main.tscn").instantiate()
	root.add_child(main)
	manager.enter_map(map_id)
	var state = root.get_node("GameState")
	state.current_map_id = map_id
	state.player_pos = pos
	state.player_facing = facing
	main._on_loaded()
	for i in 15:
		await process_frame
	print("NPC_PREVIEW_READY: %s / %s / %s" % [npc_id, map_id, pos])
	if not capture.is_empty():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture.get_base_dir()))
		if root.get_texture().get_image().save_webp(capture) != OK:
			_fail("Capture failed: " + capture)
			return
		print("NPC_CAPTURE: " + capture)
	if verify:
		var move := InputEventAction.new()
		move.action = "move_forward"
		move.pressed = true
		main._player._unhandled_input(move)
		await main._player.settle()
		if main._dialogue_overlay.is_open() or not main._player._enabled:
			_fail("Walking into or bumping an NPC must not open dialogue")
			return
		if bool(target.get("blocks", false)) and main._player._pos != pos:
			_fail("Player entered a blocking NPC cell")
			return
		if not bool(target.get("blocks", false)) and main._player._pos != target["pos"]:
			_fail("Player could not enter a passable NPC cell")
			return
		if not bool(target.get("blocks", false)):
			var back := InputEventAction.new()
			back.action = "move_back"
			back.pressed = true
			main._player._unhandled_input(back)
			await main._player.settle()
		var space := InputEventKey.new()
		space.keycode = KEY_SPACE
		space.pressed = true
		main._unhandled_input(space)
		if not main._dialogue_overlay.is_open() or main._player._enabled or main._player._pos != pos:
			_fail("Space must open dialogue from the adjacent cell and lock movement")
			return
		# 瑪歌 sample 的第一個選項接受任務，第二次選第一項返回探索。
		if npc_id == "margo":
			for i in 2:
				var key := InputEventKey.new()
				key.keycode = KEY_1
				key.pressed = true
				main._dialogue_overlay._unhandled_input(key)
				await process_frame
			if not state.quests.has("oak_antidote") or main._dialogue_overlay.is_open() or not main._player._enabled:
				_fail("Margo quest acceptance / return to exploration failed")
				return
			# sample 必須可穿越，關閉對話後可沿同方向走出 NPC 格。
			if not main._world_grid.is_walkable(target["pos"]):
				_fail("Margo sample must remain passable")
				return
			for step in 2:
				main._player._unhandled_input(move)
				await main._player.settle()
			if main._player._pos != target["pos"] + directions[facing] or main._dialogue_overlay.is_open():
				_fail("Player could not continue through Margo after dialogue")
				return
		print("NPC_DIALOGUE_OK: " + npc_id)
	if verify or not capture.is_empty():
		# 自動驗證會在聲音仍播放時結束，先讓音訊執行緒釋放 playback。
		var audio = root.get_node("AudioManager")
		audio.stop_music()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
		main.queue_free()
		await create_timer(0.1).timeout
		quit(0)

func _fail(message: String) -> void:
	printerr(message)
	quit(1)
