extends GutTest

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func _nodes() -> Array:
	return [
		{ "id": "a", "name": "甲地" },
		{ "id": "b", "name": "乙地" },
	]

func test_open_renders_names() -> void:
	var o := TravelOverlay.new()
	add_child_autofree(o)
	o.open(_nodes())
	assert_true(o.is_open())
	assert_string_contains(o.list_text(), "甲地")
	assert_string_contains(o.list_text(), "乙地")

func test_enter_emits_chosen_with_cursor_node() -> void:
	var o := TravelOverlay.new()
	add_child_autofree(o)
	o.open(_nodes())
	watch_signals(o)
	o._unhandled_input(_key(KEY_DOWN))
	o._unhandled_input(_key(KEY_ENTER))
	assert_signal_emitted(o, "travel_chosen")
	var n: Dictionary = get_signal_parameters(o, "travel_chosen")[0]
	assert_eq(String(n["id"]), "b")
	assert_false(o.is_open())

func test_escape_closes_and_finishes() -> void:
	var o := TravelOverlay.new()
	add_child_autofree(o)
	o.open(_nodes())
	watch_signals(o)
	o._unhandled_input(_key(KEY_ESCAPE))
	assert_signal_emitted(o, "finished")
	assert_false(o.is_open())

func test_empty_list_shows_placeholder_and_enter_noop() -> void:
	var o := TravelOverlay.new()
	add_child_autofree(o)
	o.open([])
	watch_signals(o)
	o._unhandled_input(_key(KEY_ENTER))
	assert_signal_not_emitted(o, "travel_chosen")
	assert_string_contains(o.list_text(), "沒有")
