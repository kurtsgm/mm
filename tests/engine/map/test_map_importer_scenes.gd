extends GutTest

func _p(d) -> MapData:
	return MapImporter.parse(JSON.stringify(d))

func test_scene_parsed():
	var m := _p({
		"grid": ["@."],
		"entities": [ {"type": "scene", "pos": [1, 0], "dialogue": "shop_oak"} ],
	})
	assert_not_null(m)
	assert_true(m.has_scene(Vector2i(1, 0)))
	var s := m.get_scene(Vector2i(1, 0))
	assert_eq(s["dialogue"], "shop_oak")
	assert_eq(s["once"], false)
	assert_eq(s["require"], null)

func test_scene_with_require_and_once():
	var m := _p({
		"grid": ["@."],
		"entities": [ {"type": "scene", "pos": [1, 0], "dialogue": "d",
			"require": {"flag": "x", "is": true}, "once": true} ],
	})
	var s := m.get_scene(Vector2i(1, 0))
	assert_eq(s["once"], true)
	assert_eq(s["require"], {"flag": "x", "is": true})

func test_scene_missing_dialogue_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [ {"type": "scene", "pos": [1, 0]} ]}))

func test_scene_with_cutscene_parses():
	# scene entity 可只帶 cutscene（無 dialogue）；該鍵透傳到 get_scene，供 main._try_scene 分支。
	var m := _p({
		"grid": ["@."],
		"entities": [ {"type": "scene", "pos": [1, 0], "cutscene": "nav_echo_nest",
			"require": {"quest_active": "goblin_menace"}, "once": true} ],
	})
	assert_not_null(m)
	assert_true(m.has_scene(Vector2i(1, 0)))
	var s := m.get_scene(Vector2i(1, 0))
	assert_eq(s["cutscene"], "nav_echo_nest")
	assert_false(s.has("dialogue"), "cutscene-only scene 不帶 dialogue 鍵")
	assert_eq(s["once"], true)
	assert_eq(s["require"], {"quest_active": "goblin_menace"})

func test_scene_neither_dialogue_nor_cutscene_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [ {"type": "scene", "pos": [1, 0], "once": true} ]}))

func test_scene_out_of_bounds_returns_null():
	assert_null(_p({"grid": ["@"], "entities": [ {"type": "scene", "pos": [5, 0], "dialogue": "d"} ]}))

func test_no_scenes_empty():
	assert_eq(_p({"grid": ["@"]}).scenes, [])
