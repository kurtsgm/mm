extends GutTest

# 迴歸守門：所有 checked-in 任務內容必須通過 lint（0 error）。warning 容許但會印出。
func test_quest_content_has_no_lint_errors():
	var r := QuestLint.run()
	if not r["warnings"].is_empty():
		gut.p("quest lint warnings: %s" % str(r["warnings"]))
	assert_eq(r["errors"], [], "quest lint 發現 error：%s" % str(r["errors"]))
