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

func _init() -> void:
	layer = 90

func setup(camera: Camera3D, ctx) -> void:
	_camera = camera
	_ctx = ctx

func is_playing() -> bool:
	return _playing

func play(data: CutsceneData) -> void:
	if data == null:
		return
	_playing = true
	for step in data.steps:
		await _play_step(step)
	_playing = false
	finished.emit()

func _play_step(step: Dictionary) -> void:
	match String(step.get("type", "")):
		"wait":
			await get_tree().create_timer(float(step["duration"])).timeout
		"effects":
			var descs := DialogueEffects.apply(step["effects"], _ctx)
			if descs.size() > 0:
				dialogue_advanced.emit(descs)
		"audio":
			_play_audio(step)
		_:
			pass  # fade/cg/title/shake/dialogue 由後續 Task 補；未知型別略過

func _play_audio(step: Dictionary) -> void:
	match String(step["op"]):
		"sfx":
			AudioManager.play_sfx(String(step["id"]))
		"bgm":
			AudioManager.play_map_bgm(String(step["id"]))
		"stop":
			AudioManager.stop_music()
