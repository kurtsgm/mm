extends GutTest

func test_open_lists_rows_and_is_open():
	var cl := CombatChoiceList.new()
	add_child_autofree(cl)
	cl.open("施法", ["火球 SP3", "治癒 SP2"])
	assert_true(cl.is_open())
	assert_true(cl._label.text.contains("火球"))
	assert_true(cl._label.text.contains("[1]"))

func test_choose_emits_index():
	var cl := CombatChoiceList.new()
	add_child_autofree(cl)
	cl.open("道具", ["藥水"])
	watch_signals(cl)
	cl.choose(0)
	assert_signal_emitted_with_parameters(cl, "chosen", [0])

func test_close_hides():
	var cl := CombatChoiceList.new()
	add_child_autofree(cl)
	cl.open("施法", ["x"]); cl.close()
	assert_false(cl.is_open())
