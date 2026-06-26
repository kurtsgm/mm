extends GutTest

func _raw() -> Dictionary:
	return {
		"id": "d1", "start": "root",
		"nodes": {
			"root": {
				"text": "hi", "image": "img1",
				"choices": [
					{ "text": "go", "goto": "n2" },
					{ "text": "bye", "goto": null },
				],
			},
			"n2": { "text": "there", "choices": [ {"text": "ok", "goto": null} ] },
		},
	}

func test_parse_valid():
	var d := DialogueData.parse(_raw())
	assert_not_null(d)
	assert_eq(d.id, "d1")
	assert_eq(d.start, "root")
	assert_true(d.has_node("root"))
	assert_eq(d.node("root")["text"], "hi")
	assert_eq(d.node("root")["image"], "img1")
	assert_eq(d.node("root")["choices"].size(), 2)

func test_missing_image_defaults_empty():
	var raw := _raw()
	raw["nodes"]["n2"].erase("image")
	assert_eq(DialogueData.parse(raw).node("n2")["image"], "")

func test_choice_defaults():
	var d := DialogueData.parse(_raw())
	var c: Dictionary = d.node("n2")["choices"][0]
	assert_eq(c["require"], null)
	assert_eq(c["effects"], [])
	assert_eq(c["goto"], null)

func test_missing_start_returns_null():
	var raw := _raw()
	raw.erase("start")
	assert_null(DialogueData.parse(raw))

func test_start_not_in_nodes_returns_null():
	var raw := _raw()
	raw["start"] = "nope"
	assert_null(DialogueData.parse(raw))

func test_nodes_not_dict_returns_null():
	assert_null(DialogueData.parse({"id": "d", "start": "root", "nodes": []}))

func test_goto_dangling_returns_null():
	var raw := _raw()
	raw["nodes"]["root"]["choices"][0]["goto"] = "ghost"
	assert_null(DialogueData.parse(raw))

func test_unknown_node_returns_empty():
	assert_eq(DialogueData.parse(_raw()).node("ghost"), {})
