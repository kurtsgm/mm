extends GutTest

func test_bestiary_all_ids_lists_encounters():
	var ids := Bestiary.all_ids()
	assert_true(ids.has("g"))
	assert_true(ids.has("o"))
	assert_true(ids.has("ps"))
	assert_true(ids.has("dw"))
	assert_eq(ids.size(), 4)

func test_run_cell_returns_row_schema():
	var cell := SimMatrix.run_cell("g", 8, 5, 42, 5, 2)   # 小 n 求快
	assert_eq(cell["encounter"], "g")
	assert_eq(cell["level"], 8)
	assert_eq(cell["n"], 5)
	assert_true(cell["win_rate"] >= 0.0 and cell["win_rate"] <= 1.0)
	for key in ["avg_rounds", "avg_deaths", "avg_hp_pct_on_win", "timeouts"]:
		assert_true(cell.has(key), "缺 key: %s" % key)

func test_run_cell_is_deterministic_for_same_seed():
	var a := SimMatrix.run_cell("dw", 5, 4, 7, 5, 2)
	var b := SimMatrix.run_cell("dw", 5, 4, 7, 5, 2)
	assert_eq(a["win_rate"], b["win_rate"])   # 同 seed → 可複現

func test_run_all_covers_grid():
	var rows := SimMatrix.run_all([2, 3], 2, 1, 5, 2)
	assert_eq(rows.size(), 8)   # 4 遭遇 × 2 等級
