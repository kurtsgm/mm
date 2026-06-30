extends GutTest

# 迴歸守門：所有 checked-in 任務內容必須通過 lint（0 error）。warning 容許但會印出。
func test_quest_content_has_no_lint_errors():
	var r := QuestLint.run()
	if not r["warnings"].is_empty():
		gut.p("quest lint warnings: %s" % str(r["warnings"]))
	assert_eq(r["errors"], [], "quest lint 發現 error：%s" % str(r["errors"]))

func _qg_lint_map(qg_pos: Vector2i, entry_pos: Vector2i, walls: Array = []) -> MapData:
	var m := MapData.new()
	m.map_id = "t"
	m.width = 5
	m.height = 5
	var t := PackedInt32Array()
	t.resize(25)   # 全 0 = FLOOR
	for w in walls:
		t[w.y * 5 + w.x] = MapData.TileType.WALL
	m.tiles = t
	m.entries = {"e": {"pos": entry_pos, "facing": 0}}
	m.quest_givers = [{"pos": qg_pos, "dialogue": "q", "sprite": ""}]
	return m

func test_questgiver_on_entry_is_error():
	var m := _qg_lint_map(Vector2i(2, 2), Vector2i(2, 2))
	assert_false(QuestLint.questgiver_placement_errors("t", m).is_empty(), "壓在入口格 → error")

func test_questgiver_surrounded_by_walls_is_error():
	var m := _qg_lint_map(Vector2i(2, 2), Vector2i(0, 0),
		[Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)])
	assert_false(QuestLint.questgiver_placement_errors("t", m).is_empty(), "四鄰皆牆 → error")

func test_valid_questgiver_placement_no_error():
	var m := _qg_lint_map(Vector2i(2, 2), Vector2i(0, 0))
	assert_eq(QuestLint.questgiver_placement_errors("t", m), [], "開放地板、非入口 → 無 error")
