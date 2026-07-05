extends GutTest

func _raw() -> Dictionary:
	return {
		"id": "cs1",
		"steps": [
			{ "type": "fade", "to": "black", "duration": 0.6 },
			{ "type": "cg", "image": "img1", "hold": 3.0 },
			{ "type": "shake", "intensity": 6.0, "duration": 0.5 },
			{ "type": "audio", "op": "sfx", "id": "sting" },
			{ "type": "dialogue", "dialogue": "d1" },
			{ "type": "title_card", "title": "第一章", "subtitle": "邊陲", "hold": 2.5 },
			{ "type": "wait", "duration": 1.0 },
			{ "type": "effects", "effects": [ {"op": "set_flag", "flag": "x"} ] },
		],
	}

func test_parse_valid():
	var d := CutsceneData.parse(_raw())
	assert_not_null(d)
	assert_eq(d.id, "cs1")
	assert_eq(d.steps.size(), 8)
	assert_eq(d.steps[0]["type"], "fade")
	assert_eq(d.steps[0]["to"], "black")

func test_defaults_applied():
	var d := CutsceneData.parse({ "id": "c", "steps": [ {"type": "fade"} ] })
	assert_eq(d.steps[0]["to"], "black")       # fade.to 預設 black
	assert_almost_eq(float(d.steps[0]["duration"]), 0.5, 0.001)

func test_top_level_not_dict_returns_null():
	assert_null(CutsceneData.parse([] as Array as Variant))

func test_steps_not_array_returns_null():
	assert_null(CutsceneData.parse({ "id": "c", "steps": {} }))

func test_unknown_type_returns_null():
	assert_null(CutsceneData.parse({ "id": "c", "steps": [ {"type": "nope"} ] }))

func test_cg_missing_image_returns_null():
	assert_null(CutsceneData.parse({ "id": "c", "steps": [ {"type": "cg"} ] }))

func test_dialogue_missing_id_returns_null():
	assert_null(CutsceneData.parse({ "id": "c", "steps": [ {"type": "dialogue"} ] }))

func test_fade_bad_to_returns_null():
	assert_null(CutsceneData.parse({ "id": "c", "steps": [ {"type": "fade", "to": "purple"} ] }))

func test_audio_bad_op_returns_null():
	assert_null(CutsceneData.parse({ "id": "c", "steps": [ {"type": "audio", "op": "boom"} ] }))

func test_step_not_dict_returns_null():
	assert_null(CutsceneData.parse({ "id": "c", "steps": [ 5 ] }))
