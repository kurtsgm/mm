class_name CutscenePlayer
extends CanvasLayer
# 資料驅動演出播放器：逐 step await（fade/title/cg/dialogue/shake/audio/wait/effects）。
# 本檔核心：play 迴圈＋wait/effects/audio。fade/cg/title/shake（step 分派見 _play_step）
# 與 dialogue 由後續實作補上。過場期間玩家已由 main disable，故安全。

signal finished
signal dialogue_advanced(descriptions: Array)

var _camera: Camera3D
var _ctx
var _playing: bool = false

var _fade_rect: ColorRect
var _cg_rect: TextureRect
var _title_card: TitleCard
var _dialogue_overlay: DialogueOverlay
var _skip_dwell: bool = false

func _init() -> void:
	layer = 90

func _ready() -> void:
	# 黑幕（fade）：全螢幕黑、alpha 由 0 動到 1。
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

	# 事件 CG：全螢幕、保長寬比置中；初始隱藏。
	_cg_rect = TextureRect.new()
	_cg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cg_rect.visible = false
	add_child(_cg_rect)

	# 標題卡：初始隱藏。
	_title_card = TitleCard.new()
	_title_card.visible = false
	add_child(_title_card)

	# 自擁 DialogueOverlay（layer 95 > 本 player 的 90 → 對話框顯示在黑幕之上）。
	# 刻意不接 main 的 _on_dialogue_finished：其負責獨立對話的收尾與 once 標記。
	# 只把 overlay 的 advanced 以本 player 的 dialogue_advanced 轉出（main 再路由到訊息列）。
	_dialogue_overlay = DialogueOverlay.new()
	add_child(_dialogue_overlay)
	_dialogue_overlay.layer = 95
	_dialogue_overlay.advanced.connect(func(descs): dialogue_advanced.emit(descs))

	set_process_unhandled_input(false)

func setup(camera: Camera3D, ctx) -> void:
	_camera = camera
	_ctx = ctx

func is_playing() -> bool:
	return _playing

func play(data: CutsceneData) -> ActionResult:
	if data == null or _playing:
		return ActionResult.failure(&"invalid_cutscene")
	# Validate required dialogue dependencies before starting visuals or committing effects.
	for step in data.steps:
		if step["type"] == "dialogue" and DialogueCatalog.load_dialogue(String(step["dialogue"])) == null:
			return ActionResult.failure(&"missing_dialogue", ["過場對話資料遺失。"])
	_playing = true
	var result := ActionResult.success()
	for step in data.steps:
		result = await _play_step(step)
		if not result.ok:
			break
	_playing = false
	if not result.ok:
		_fade_rect.color.a = 0.0
		_cg_rect.visible = false
		_title_card.visible = false
	finished.emit()
	return ActionResult.success() if result.ok else result

func _play_step(step: Dictionary) -> ActionResult:
	match String(step.get("type", "")):
		"wait":
			await get_tree().create_timer(float(step["duration"])).timeout
		"effects":
			var result := StoryEffects.apply(step["effects"], _ctx)
			if result.ok and not result.events.is_empty():
				dialogue_advanced.emit(result.events)
			return result
		"audio":
			_play_audio(step)
		"fade":
			var target: float = 1.0 if String(step["to"]) == "black" else 0.0
			var tween := create_tween()
			tween.tween_property(_fade_rect, "color:a", target, float(step["duration"]))
			await tween.finished
		"cg":
			_cg_rect.texture = SceneImageCatalog.get_texture(String(step["image"]))
			_cg_rect.visible = true
			await _dwell(float(step["hold"]))
			_cg_rect.visible = false
		"title_card":
			_title_card.set_content(String(step["title"]), String(step["subtitle"]))
			_title_card.visible = true
			await _dwell(float(step["hold"]))
			_title_card.visible = false
		"shake":
			await _shake(float(step["intensity"]), float(step["duration"]))
		"dialogue":
			var data := DialogueCatalog.load_dialogue(String(step["dialogue"]))
			if data == null:
				return ActionResult.failure(&"missing_dialogue")
			_dialogue_overlay.open(DialogueRunner.new(data, _ctx))
			await _dialogue_overlay.finished
		_:
			return ActionResult.failure(&"unsupported_step")
	return ActionResult.success()

func _play_audio(step: Dictionary) -> void:
	match String(step["op"]):
		"sfx":
			AudioManager.play_sfx(String(step["id"]))
		"bgm":
			AudioManager.play_map_bgm(String(step["id"]))
		"stop":
			AudioManager.stop_music()

# 停留 hold 秒；hold<=0 → 等按鍵。期間任意鍵可提前推進（無整段 skip）。
func _dwell(hold: float) -> void:
	_skip_dwell = false
	set_process_unhandled_input(true)
	if hold > 0.0:
		var timer := get_tree().create_timer(hold)
		while timer.time_left > 0.0 and not _skip_dwell:
			await get_tree().process_frame
	else:
		while not _skip_dwell:
			await get_tree().process_frame
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_skip_dwell = true

# 鏡頭震動：在 duration 內以衰減隨機 offset 擾動相機，結束復位。
func _shake(intensity: float, duration: float) -> void:
	if _camera == null:
		return
	var base := _camera.position
	var t := 0.0
	while t < duration:
		var dt := get_process_delta_time()
		t += dt
		var falloff: float = 1.0 - (t / duration)
		var amp: float = intensity * 0.01 * maxf(falloff, 0.0)
		_camera.position = base + Vector3(
			randf_range(-amp, amp), randf_range(-amp, amp), 0.0)
		await get_tree().process_frame
	_camera.position = base
