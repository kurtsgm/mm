extends GutTest

func _monster(n: String, hp: int, hp_max: int) -> Monster:
	var m := Monster.new()
	m.name = n; m.hp = hp; m.hp_max = hp_max; m.might = 1; m.armor = 0
	m.accuracy = 1; m.speed = 1; m.xp_reward = 1; m.gold_reward = 1
	return m

func test_plate_text_shows_number_name_hp():
	var t := EnemyPanel.plate_text(0, _monster("哥布林", 7, 12))
	assert_true(t.contains("哥布林"))
	assert_true(t.contains("7/12"))

func test_refresh_builds_one_plate_per_living():
	var panel := EnemyPanel.new()
	add_child_autofree(panel)
	panel.refresh([_monster("A", 5, 10), _monster("B", 10, 10)], -1)
	assert_eq(panel._plates.size(), 2)

func test_flash_damage_adds_number_label():
	var panel := EnemyPanel.new()
	add_child_autofree(panel)
	var a := _monster("A", 5, 10)
	panel.refresh([a], -1)
	var plate_panel: Control = panel._find_plate(a)["panel"]
	var before := plate_panel.get_child_count()
	panel.flash_damage(a, 4)
	assert_gt(plate_panel.get_child_count(), before, "跳出傷害數字 Label")
