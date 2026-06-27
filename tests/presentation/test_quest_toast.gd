extends GutTest

func test_queue_shows_first_holds_rest():
	var t := QuestToast.new()
	add_child_autofree(t)
	t.show_notice("甲")
	t.show_notice("乙")
	assert_eq(t._label.text, "甲")    # 第一則顯示中
	assert_eq(t._queue, ["乙"])       # 後續排隊
	assert_true(t._showing)

func test_idle_when_empty():
	var t := QuestToast.new()
	add_child_autofree(t)
	assert_false(t._showing)
	assert_false(t.visible)
