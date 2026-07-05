extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}
	func accept_quest(_q): pass
	func advance_quest(_q): pass

func _player(ctx) -> CutscenePlayer:
	var p := CutscenePlayer.new()
	add_child_autofree(p)
	var cam := Camera3D.new()
	add_child_autofree(cam)
	p.setup(cam, ctx)
	return p

func _data(steps: Array) -> CutsceneData:
	return CutsceneData.parse({ "id": "t", "steps": steps })

func test_effects_wait_finishes_and_mutates_ctx():
	var ctx := FakeCtx.new()
	var p := _player(ctx)
	watch_signals(p)
	await p.play(_data([
		{ "type": "effects", "effects": [ {"op": "set_flag", "flag": "seen"} ] },
		{ "type": "wait", "duration": 0.05 },
	]))
	assert_signal_emitted(p, "finished")
	assert_true(ctx.flags.get("seen", false))
	assert_false(p.is_playing())

func test_audio_bgm_step_switches_track():
	var p := _player(FakeCtx.new())
	await p.play(_data([ { "type": "audio", "op": "bgm", "id": "oak_town" } ]))
	assert_eq(AudioManager.current_track_id(), "oak_town")

func test_is_playing_true_during_play():
	# wait 步驟進行中 is_playing()==true；不 await play、給它一幀後檢查。
	var p := _player(FakeCtx.new())
	p.play(_data([ { "type": "wait", "duration": 0.3 } ]))
	await get_tree().process_frame
	assert_true(p.is_playing())
