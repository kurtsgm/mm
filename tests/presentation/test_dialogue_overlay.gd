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
	assert_almost_eq(ov._image_rect.anchor_bottom, 0.62, 0.03, "情境圖底約在 ~62%（上半部）")

func test_relayout_frames_image_centered_with_text_aligned():
	# 開啟後等版面就緒，驗證「羊皮紙緊貼情境圖、置中、對話框對齊圖左緣」。
	var ov := _overlay()
	ov.open(_runner(50))
	await wait_frames(3)
	var vp := ov.get_viewport().get_visible_rect().size
	var img: Rect2 = ov._drawn_image_rect()
	assert_gt(img.size.x, 1.0, "情境圖已畫出（有實際尺寸）")
	# 羊皮紙不再近滿版：明顯比視窗窄。
	assert_lt(ov._parchment_rect.size.x, vp.x * 0.95, "羊皮紙比視窗窄（不是近滿版）")
	# 羊皮紙框住情境圖（四邊都在圖外側）。
	var p_pos: Vector2 = ov._parchment_rect.position
	var p_sz: Vector2 = ov._parchment_rect.size
	assert_lte(p_pos.x, img.position.x, "羊皮紙左緣在圖左緣外側")
	assert_gte(p_pos.x + p_sz.x, img.position.x + img.size.x, "羊皮紙右緣在圖右緣外側")
	# 卡片水平置中：左右留白接近相等。
	var margin_l: float = p_pos.x
	var margin_r: float = vp.x - (p_pos.x + p_sz.x)
	assert_almost_eq(margin_l, margin_r, vp.x * 0.02, "羊皮紙水平置中（左右留白相近）")
	# 對話框貼在圖正下方，左右各內縮 → 文字兩側有留白、不貼圖緣。
	assert_gt(ov._box.position.y, img.position.y + img.size.y - 1.0, "對話框在情境圖下方")
	var inset_l: float = ov._box.position.x - img.position.x
	var inset_r: float = (img.position.x + img.size.x) - (ov._box.position.x + ov._box.size.x)
	assert_gt(inset_l, 1.0, "對話框左緣在圖左緣內側（左留白）")
	assert_almost_eq(inset_l, inset_r, 1.0, "左右內縮對稱（兩側留白相等）")

func test_text_box_in_bottom_region():
	var ov := _overlay()
	# 對話框是 _text_label 的父鏈最外層 Control；用其全域 anchor 反推：文字落在下方 ~30%
	assert_gt(ov._text_label.get_parent().get_parent().anchor_top, 0.6, "對話文字落在下半部")

func test_image_rect_has_feather_material():
	var ov := _overlay()
	assert_true(ov._image_rect.material is ShaderMaterial, "情境圖套羽化 shader 融入羊皮紙")
