extends GutTest

func before_all():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id; d.display_name = "鐵劍"; d.category = ItemDef.Category.WEAPON; d.attack = 6; d.value = 30; return d

func after_all():
	ItemInstance.base_resolver = Callable()

func test_colored_name_wraps_bbcode_color():
	var it := ItemInstance.new(); it.base_id = "iron_sword"; it.quality = Quality.Q.RARE
	var s := ItemDisplay.colored_name(it)
	assert_true(s.begins_with("[color=#"))
	assert_true(s.find("鐵劍") != -1)

func test_detail_lines_list_affixes():
	var it := ItemInstance.new(); it.base_id = "iron_sword"; it.quality = Quality.Q.FINE
	it.ilvl = 20
	it.affixes = [{"id": "of_the_bear", "kind": 1, "mods": {ItemStat.S.MIGHT: 5}}]
	var lines := ItemDisplay.detail_lines(it)
	var joined := "\n".join(lines)
	assert_true(joined.find("力量 +5") != -1)
	assert_true(joined.find("ilvl 20") != -1)
