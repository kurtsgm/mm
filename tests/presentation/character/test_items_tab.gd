extends GutTest

func _member() -> Character:
	var c := Character.new()
	c.name = "亞爾"
	c.char_class = "Knight"
	c.level = 1
	c.hp = 5
	c.hp_max = 30
	c.sp = 0
	c.sp_max = 0
	return c

func _inv(pairs: Dictionary) -> Inventory:
	var inv := Inventory.new()
	for id in pairs:
		inv.add(id, int(pairs[id]))
	return inv

func test_rows_lead_with_three_equip_slots():
	var rows := CharacterItemsTab.rows(_member(), _inv({"potion": 2}))
	assert_eq(rows.size(), 4, "3 裝備槽 + 1 背包列")
	assert_eq(String(rows[0]["kind"]), "equip")
	assert_eq(String(rows[1]["kind"]), "equip")
	assert_eq(String(rows[2]["kind"]), "equip")
	assert_eq(String(rows[3]["kind"]), "item")
	assert_eq(String(rows[3]["id"]), "potion")

func test_lines_mark_cursor_and_sections():
	var rows := CharacterItemsTab.rows(_member(), _inv({"potion": 2}))
	var text := "\n".join(CharacterItemsTab.lines(rows, 3))
	assert_true(text.contains("裝備"), "有裝備區塊標題")
	assert_true(text.contains("背包"), "有背包區塊標題")
	assert_true(text.contains("> "), "有游標標記")

func test_activate_consumable_uses_and_decrements():
	var m := _member()
	var inv := _inv({"potion": 2})
	var rows := CharacterItemsTab.rows(m, inv)
	var events := CharacterItemsTab.activate(rows[3], m, inv)  # potion
	assert_false(events.is_empty(), "使用回傳事件")
	assert_gt(m.hp, 5, "HP 回復")
	assert_eq(inv.count_of("potion"), 1, "背包減一")

func test_activate_equippable_equips_and_removes_from_inv():
	var m := _member()
	var inv := _inv({"short_sword": 1})
	var rows := CharacterItemsTab.rows(m, inv)
	CharacterItemsTab.activate(rows[3], m, inv)  # short_sword
	assert_true(m.equipment.is_equipped(Equipment.Slot.WEAPON), "武器槽已裝備")
	assert_eq(inv.count_of("short_sword"), 0, "背包扣除")

func test_activate_equipped_slot_unequips_back_to_inv():
	var m := _member()
	var inv := _inv({})   # 背包起始為空；下面直接裝備一把短劍，卸下後背包才會恰好 1 把
	m.equipment.equip(ItemCatalog.get_item("short_sword"))
	var rows := CharacterItemsTab.rows(m, inv)
	# rows[0] = 武器槽（已裝 short_sword）
	var events := CharacterItemsTab.activate(rows[0], m, inv)
	assert_false(events.is_empty(), "卸下回傳事件")
	assert_false(m.equipment.is_equipped(Equipment.Slot.WEAPON), "武器槽已空")
	assert_eq(inv.count_of("short_sword"), 1, "回到背包")
