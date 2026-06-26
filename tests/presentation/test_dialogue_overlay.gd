extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev

func _runner(gold := 0) -> DialogueRunner:
	var data := DialogueData.parse({
		"id": "d", "start": "root",
		"nodes": {
			"root": {
				"text": "hi", "image": "demo_event",
				"choices": [
					{ "text": "buy", "require": {"gold_gte": 30},
					  "effects": [{"op": "gold", "value": -30}], "goto": "bought" },
					{ "text": "leave", "goto": null },
				],
			},
			"bought": { "text": "thanks", "choices": [ {"text": "ok", "goto": null} ] },
		},
	})
	var c := FakeCtx.new()
	c.gold = gold
	return DialogueRunner.new(data, c)

func _overlay() -> DialogueOverlay:
	var ov := DialogueOverlay.new()
	add_child_autofree(ov)
	return ov

func test_open_renders_text_and_choices():
	var ov := _overlay()
	ov.open(_runner(50))
	assert_true(ov.is_open())
	assert_eq(ov._text_label.text, "hi")
	assert_eq(ov._choice_box.get_child_count(), 2)   # buy + leave（gold 足夠）
	assert_not_null(ov._image_rect.texture)

func test_choices_filtered_by_require():
	var ov := _overlay()
	ov.open(_runner(0))
	assert_eq(ov._choice_box.get_child_count(), 1)    # 只有 leave

func test_choice_advances_to_next_node():
	var ov := _overlay()
	ov.open(_runner(50))
	ov._unhandled_input(_key(KEY_1))                  # 選 buy
	assert_eq(ov._text_label.text, "thanks")
	assert_true(ov.is_open())

func test_advanced_signal_carries_descriptions():
	var ov := _overlay()
	ov.open(_runner(50))
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_1))                  # buy → effects 有描述
	assert_signal_emitted(ov, "advanced")

func test_goto_null_finishes_and_closes():
	var ov := _overlay()
	ov.open(_runner(0))
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_1))                  # 唯一選項 leave（goto null）
	assert_signal_emitted(ov, "finished")
	assert_false(ov.is_open())
