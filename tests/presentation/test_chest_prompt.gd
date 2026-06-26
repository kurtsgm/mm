extends GutTest

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev

func _prompt() -> ChestPrompt:
	var p := ChestPrompt.new()
	add_child_autofree(p)
	return p

func test_starts_closed():
	assert_false(_prompt().is_open())

func test_open_then_y_confirms_and_closes():
	var p := _prompt()
	p.open()
	assert_true(p.is_open())
	watch_signals(p)
	p._unhandled_input(_key(KEY_Y))
	assert_signal_emitted(p, "confirmed")
	assert_false(p.is_open())

func test_open_then_n_declines_and_closes():
	var p := _prompt()
	p.open()
	watch_signals(p)
	p._unhandled_input(_key(KEY_N))
	assert_signal_emitted(p, "declined")
	assert_false(p.is_open())

func test_closed_ignores_keys():
	var p := _prompt()
	watch_signals(p)
	p._unhandled_input(_key(KEY_Y))
	assert_signal_not_emitted(p, "confirmed")
