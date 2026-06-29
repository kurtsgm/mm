extends GutTest

func _knight() -> Character:
	var c := Character.new()
	c.name = "亞爾"
	c.char_class = "Knight"
	c.level = 3
	c.experience = 50
	c.hp = 20
	c.hp_max = 42
	c.sp = 0
	c.sp_max = 0
	c.might = 18
	c.intellect = 8
	c.personality = 8
	c.endurance = 20
	c.speed = 11
	c.accuracy = 13
	c.luck = 9
	return c

func test_lines_show_identity_and_level():
	var text := "\n".join(CharacterStatusTab.lines(_knight()))
	assert_true(text.contains("亞爾"), "顯示名字")
	assert_true(text.contains("Lv3"), "顯示等級")
	assert_true(text.contains("騎士"), "顯示職業中文")

func test_lines_show_xp_to_next():
	# Lv3→4 需 Leveling.xp_for_level(3)；距下一級 = 該值 - experience(50)
	var need := Leveling.xp_for_level(3)
	var text := "\n".join(CharacterStatusTab.lines(_knight()))
	assert_true(text.contains(str(need)), "顯示本級門檻")
	assert_true(text.contains(str(maxi(0, need - 50))), "顯示距下一級")

func test_lines_show_stats_and_derived():
	var c := _knight()
	var text := "\n".join(CharacterStatusTab.lines(c))
	assert_true(text.contains("力量 18"), "顯示七圍")
	# 衍生：攻擊=might(18)+裝備0+狀態0；防禦=endurance/4=5；命中=accuracy 13
	assert_true(text.contains("攻擊 %d" % c.attack_power()), "顯示攻擊")
	assert_true(text.contains("防禦 %d" % c.armor_value()), "顯示防禦")
	assert_true(text.contains("命中 %d" % c.effective_accuracy()), "顯示命中")

func test_lines_show_statuses_or_none():
	var c := _knight()
	assert_true("\n".join(CharacterStatusTab.lines(c)).contains("無"), "無異常時顯示『無』")
	c.statuses = [StatusCatalog.poison(2, 3)]
	assert_true("\n".join(CharacterStatusTab.lines(c)).contains("毒"), "中毒時顯示『毒』")

func test_fields_structured_values():
	var c := _knight()   # 既有 helper：Knight Lv3, exp50, hp20/42, might18, endurance20, accuracy13...
	var f := CharacterStatusTab.fields(c)
	assert_eq(String(f["name"]), "亞爾")
	assert_eq(String(f["class_label"]), "騎士")
	assert_eq(int(f["level"]), 3)
	assert_eq(int(f["xp"]), 50)
	assert_eq(int(f["xp_need"]), Leveling.xp_for_level(3))
	assert_eq(int(f["xp_to_next"]), maxi(0, Leveling.xp_for_level(3) - 50))
	assert_eq(int(f["stats"]["might"]), 18)
	assert_eq(int(f["attack"]), c.attack_power())
	assert_eq(int(f["armor"]), c.armor_value())
	assert_eq(int(f["accuracy_eff"]), c.effective_accuracy())
	assert_eq(String(f["condition_label"]), "正常")

func test_fields_statuses_label_color():
	var c := _knight()
	assert_eq((CharacterStatusTab.fields(c)["statuses"] as Array).size(), 0)
	c.statuses = [StatusCatalog.poison(2, 3)]
	var st: Array = CharacterStatusTab.fields(c)["statuses"]
	assert_eq(st.size(), 1)
	assert_eq(String(st[0]["label"]), "毒")
	assert_eq(st[0]["color"], StatusRules.color(c.statuses[0]))
