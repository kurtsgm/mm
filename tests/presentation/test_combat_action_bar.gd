extends GutTest

func test_label_for_known_ids():
	assert_eq(CombatActionBar.label_for("attack"), "攻擊")
	assert_eq(CombatActionBar.label_for("item"), "道具")

func test_show_actions_builds_buttons():
	var bar := CombatActionBar.new()
	add_child_autofree(bar)
	bar.show_actions(["attack", "defend", "run"])
	assert_eq(bar._buttons.size(), 3)

func test_button_emits_action_selected():
	var bar := CombatActionBar.new()
	add_child_autofree(bar)
	bar.show_actions(["attack"])
	watch_signals(bar)
	bar._buttons[0].emit_signal("pressed")
	assert_signal_emitted_with_parameters(bar, "action_selected", ["attack"])
