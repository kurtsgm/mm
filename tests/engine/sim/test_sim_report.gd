extends GutTest

func _row() -> Dictionary:
	return {"encounter": "g", "level": 3, "win_rate": 0.8, "avg_rounds": 4.5, "avg_deaths": 0.5, "avg_hp_pct_on_win": 0.6, "timeouts": 0, "n": 500}

func test_csv_has_header_and_row():
	var csv := SimReport.to_csv([_row()])
	assert_string_contains(csv, "encounter,level,win_rate,avg_rounds,avg_deaths,avg_hp_pct_on_win,timeouts,n")
	assert_string_contains(csv, "g,3,0.800")

func test_markdown_has_encounter_and_winrate():
	var md := SimReport.to_markdown([_row()], {"n": 500, "seed": 1})
	assert_string_contains(md, "遭遇 `g`")
	assert_string_contains(md, "80%")
	assert_string_contains(md, "N：500")
	assert_string_contains(md, "per-class")

func test_markdown_groups_by_encounter():
	var rows := [_row(), {"encounter": "o", "level": 3, "win_rate": 0.2, "avg_rounds": 8.0, "avg_deaths": 3.0, "avg_hp_pct_on_win": 0.1, "timeouts": 0, "n": 500}]
	var md := SimReport.to_markdown(rows, {"n": 500, "seed": 1})
	assert_string_contains(md, "遭遇 `g`")
	assert_string_contains(md, "遭遇 `o`")
