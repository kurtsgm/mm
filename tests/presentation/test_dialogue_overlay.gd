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

func _dead_end_runner() -> DialogueRunner:
	# 末端節點作者未給 choices（parse 成 []）→ 零可選項，避免 soft-lock 的情境。
	var data := DialogueData.parse({
		"id": "d", "start": "root",
		"nodes": {
			"root": { "text": "the end", "image": "demo_event", "choices": [] },
		},
	})
	return DialogueRunner.new(data, FakeCtx.new())

func test_empty_choices_dismisses_with_any_key_and_finishes():
	var ov := _overlay()
	ov.open(_dead_end_runner())
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_SPACE))             # 非數字鍵；零選項時任意鍵離開
	assert_signal_emitted(ov, "finished")
	assert_false(ov.is_open())

func test_parchment_is_near_full_screen():
	var ov := _overlay()
	assert_lt(ov._parchment_rect.anchor_left, 0.06, "羊皮紙近滿版（左邊很小）")
	assert_gt(ov._parchment_rect.anchor_right, 0.94, "羊皮紙近滿版（右邊很大）")

func test_image_occupies_top_region():
	var ov := _overlay()
	assert_lt(ov._image_rect.anchor_top, 0.15, "情境圖貼近頂部")
	assert_almost_eq(ov._image_rect.anchor_bottom, 0.66, 0.03, "情境圖底約在 ~66%（上 ~70%）")

func test_text_box_in_bottom_region():
	var ov := _overlay()
	# 對話框是 _text_label 的父鏈最外層 Control；用其全域 anchor 反推：文字落在下方 ~30%
	assert_gt(ov._text_label.get_parent().get_parent().anchor_top, 0.6, "對話文字落在下半部")
