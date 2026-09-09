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

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev

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

func test_fade_black_sets_overlay_opaque():
	var p := _player(FakeCtx.new())
	await p.play(_data([ { "type": "fade", "to": "black", "duration": 0.05 } ]))
	assert_almost_eq(p._fade_rect.color.a, 1.0, 0.01)

func test_fade_clear_sets_overlay_transparent():
	var p := _player(FakeCtx.new())
	await p.play(_data([
		{ "type": "fade", "to": "black", "duration": 0.05 },
		{ "type": "fade", "to": "clear", "duration": 0.05 },
	]))
	assert_almost_eq(p._fade_rect.color.a, 0.0, 0.01)

func test_cg_sets_texture_then_finishes():
	var p := _player(FakeCtx.new())
	await p.play(_data([ { "type": "cg", "image": "nav_echo_relic", "hold": 0.05 } ]))
	assert_not_null(p._cg_rect.texture)

func test_title_card_shows_content():
	var p := _player(FakeCtx.new())
	await p.play(_data([ { "type": "title_card", "title": "第一章", "subtitle": "邊陲", "hold": 0.05 } ]))
	# 播完標題卡不再可見，但曾設過內容（用 title label 驗）。
	assert_eq(p._title_card._title_label.text, "第一章")

func test_shake_restores_camera_transform():
	var p := _player(FakeCtx.new())
	var before := p._camera.position
	await p.play(_data([ { "type": "shake", "intensity": 4.0, "duration": 0.05 } ]))
	assert_almost_eq(p._camera.position.x, before.x, 0.001)
	assert_almost_eq(p._camera.position.y, before.y, 0.001)
	assert_almost_eq(p._camera.position.z, before.z, 0.001)

func test_dialogue_step_opens_and_completes():
	# 重用 nav_echo_nest，驗證多頁事件只在最後一頁結束過場。
	# 玩家自擁 _dialogue_overlay（layer 95），dialogue step 開它並 await finished。
	var p := _player(FakeCtx.new())
	watch_signals(p)
	# 不 await play：dialogue step 會卡在 overlay.finished；給一幀後模擬按鍵完成。
	p.play(_data([ { "type": "dialogue", "dialogue": "nav_echo_nest" } ]))
	await get_tree().process_frame
	assert_true(p._dialogue_overlay.is_open(), "對話 overlay 已開")
	assert_eq(p._dialogue_overlay.layer, 95, "自擁 overlay 疊在黑幕之上")
	p._dialogue_overlay._unhandled_input(_key(KEY_1))
	assert_true(p.is_playing(), "第一頁之後仍維持過場鎖定")
	assert_signal_not_emitted(p, "finished")
	for i in range(10):
		if not p._dialogue_overlay.is_open():
			break
		p._dialogue_overlay._unhandled_input(_key(KEY_1))
		await get_tree().process_frame
	await get_tree().process_frame
	assert_signal_emitted(p, "finished")
	assert_false(p._dialogue_overlay.is_open())
