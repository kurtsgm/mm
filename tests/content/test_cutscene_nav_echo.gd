extends GutTest

func test_nav_echo_cutscene_parses():
	var d := CutsceneCatalog.load("nav_echo_nest")
	assert_not_null(d, "nav_echo_nest 過場可載並 parse")
	# 至少含 fade→cg→dialogue 幾個關鍵 step。
	var types: Array = []
	for s in d.steps:
		types.append(s["type"])
	assert_true(types.has("fade"), "含 fade")
	assert_true(types.has("cg"), "含 cg")
	assert_true(types.has("dialogue"), "含 dialogue")

func test_nav_echo_dialogue_still_exists():
	# dialogue step 重用既有 nav_echo_nest 對話（低語文字不重寫）。
	assert_not_null(DialogueCatalog.load_dialogue("nav_echo_nest"))

func test_wild_ne_scene_uses_cutscene():
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/wild_ne.json"))
	var found := false
	for e in raw["entities"]:
		# JSON.parse_string 把數字讀成 float，故 pos 為 [9.0, 9.0]；正規化成 int 再比對。
		var pos = e.get("pos", [])
		if String(e.get("type", "")) == "scene" and pos.size() == 2 and int(pos[0]) == 9 and int(pos[1]) == 9:
			found = true
			assert_true(e.has("cutscene"), "(9,9) scene 用 cutscene 鍵")
			assert_eq(String(e["cutscene"]), "nav_echo_nest")
			assert_false(e.has("dialogue"), "不再用 dialogue 鍵")
	assert_true(found, "找到 (9,9) scene entity")
