extends GutTest

func _report() -> Dictionary:
	return {
		"fights": [
			{"index": 0, "encounter": "g", "party_level": 1, "xp_total": 60, "victory": true, "avg_level": 1.5},
			{"index": 1, "encounter": "g", "party_level": 1, "xp_total": 60, "victory": true, "avg_level": 2.0},
			{"index": 2, "encounter": "o", "party_level": 2, "xp_total": 80, "victory": true, "avg_level": 3.0},
		],
		"fights_per_level": {1: 2, 2: 1},
		"reached_target": true,
		"final_min_level": 3,
		"final_avg_level": 3.0,
		"target_level": 3,
		"win_threshold": 0.7,
	}

func test_markdown_has_rest_assumption_and_target():
	var md := ProgressionReport.to_markdown(_report(), {"seed": 1, "trials": 12})
	assert_string_contains(md, "完整休息")          # 場間全休假設註明
	assert_string_contains(md, "目標等級")
	assert_string_contains(md, "勝率門檻")

func test_markdown_has_fights_per_level_and_encounter_usage():
	var md := ProgressionReport.to_markdown(_report(), {"seed": 1, "trials": 12})
	assert_string_contains(md, "每級場數")
	assert_string_contains(md, "`g`")              # 用過的遭遇
	assert_string_contains(md, "`o`")

func test_markdown_reports_reached_target():
	var md := ProgressionReport.to_markdown(_report(), {"seed": 1, "trials": 12})
	assert_string_contains(md, "達標")
