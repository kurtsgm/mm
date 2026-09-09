class_name NarrativeScene
extends RefCounted

## A scene's origin is captured before awaiting playback. Only successful completion consumes once.
var dialogue: DialogueData
var cutscene: CutsceneData
var _state
var _map_id: String
var _pos: Vector2i
var _once: bool
var _finished := false

func _init(state, map_id: String, pos: Vector2i, once: bool) -> void:
	_state = state
	_map_id = map_id
	_pos = pos
	_once = once

func complete(success: bool) -> void:
	if _finished:
		return
	_finished = true
	if success and _once:
		_state.mark_scene_triggered(_map_id, _pos)
	if success:
		_state.refresh_collect()
