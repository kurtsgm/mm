extends GutTest

func test_push_shows_recent_lines():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.push("甲")
	log.push("乙")
	assert_true(log._label.text.contains("甲"))
	assert_true(log._label.text.contains("乙"))

func test_keeps_only_last_max_lines():
	var log := CombatLog.new()
	add_child_autofree(log)
	for i in 20:
		log.push("行%d" % i)
	assert_false(log._label.text.contains("行0"), "最舊的被丟掉")
	assert_true(log._label.text.contains("行19"))

func test_clear_empties():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.push("甲"); log.clear()
	assert_eq(log._label.text, "")
