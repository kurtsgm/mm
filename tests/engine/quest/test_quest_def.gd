extends GutTest

func _raw() -> Dictionary:
	return {
		"id": "q1", "title": "測試任務",
		"stages": [
			{"type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "前往"},
			{"type": "kill", "monster": "goblin", "count": 3, "desc": "擊敗哥布林"},
			{"type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得信物"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 100, "items": ["potion"]},
	}

func test_parse_valid():
	var d := QuestDef.parse(_raw())
	assert_not_null(d)
	assert_eq(d.id, "q1")
	assert_eq(d.title, "測試任務")
	assert_eq(d.stage_count(), 4)
	assert_eq(d.rewards["gold"], 100)

func test_reach_pos_normalized_to_vector2i():
	var d := QuestDef.parse(_raw())
	assert_eq(d.stage(0)["pos"], Vector2i(3, 3))

func test_kill_fields():
	var d := QuestDef.parse(_raw())
	assert_eq(d.stage(1)["monster"], "goblin")
	assert_eq(d.stage(1)["count"], 3)

func test_empty_stages_rejected():
	var r := _raw(); r["stages"] = []
	assert_null(QuestDef.parse(r))

func test_unknown_stage_type_rejected():
	var r := _raw(); r["stages"] = [{"type": "wat", "desc": "x"}]
	assert_null(QuestDef.parse(r))

func test_kill_missing_count_rejected():
	var r := _raw(); r["stages"] = [{"type": "kill", "monster": "goblin", "desc": "x"}]
	assert_null(QuestDef.parse(r))

func test_reach_bad_pos_rejected():
	var r := _raw(); r["stages"] = [{"type": "reach", "map": "m", "pos": [1], "desc": "x"}]
	assert_null(QuestDef.parse(r))

func test_non_dict_rejected():
	assert_null(QuestDef.parse({}))

func test_rewards_default_empty():
	var r := _raw(); r.erase("rewards")
	var d := QuestDef.parse(r)
	assert_eq(d.rewards.get("gold", 0), 0)
	assert_eq(d.rewards.get("items", []), [])
