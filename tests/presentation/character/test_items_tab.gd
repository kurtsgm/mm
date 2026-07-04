extends GutTest

func before_all():
	# 裝備實例需 base_resolver 解析 base_def（display_name/total_attack…）。
	ItemCatalog.install_resolver()

func after_all():
	ItemInstance.base_resolver = Callable()

func _sword_inst() -> ItemInstance:
	var it := ItemInstance.new()
	it.base_id = "short_sword"   # .tres attack 6
	return it

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

func test_equip_row_includes_weapon_stat():
	var m := _member()
	m.equipment.equip(_sword_inst())  # attack 6
	var rows := CharacterItemsTab.rows(m, _inv({}))
	assert_eq(String(rows[0]["stat"]), "+6", "武器槽顯示攻擊加成")

func test_empty_equip_slot_has_blank_stat():
	var rows := CharacterItemsTab.rows(_member(), _inv({}))
	assert_eq(String(rows[2]["stat"]), "", "空飾品槽無數值")

func test_item_row_includes_category():
	var rows := CharacterItemsTab.rows(_member(), _inv({"potion": 2}))
	assert_eq(int(rows[3]["category"]), ItemDef.Category.CONSUMABLE, "背包列帶分類")

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
	var inv := Inventory.new()
	inv.add_instance(_sword_inst())
	var rows := CharacterItemsTab.rows(m, inv)
	# rows = 3 裝備槽 + 1 背包裝備實例列（index 3）
	CharacterItemsTab.activate(rows[3], m, inv)  # short_sword 實例
	assert_true(m.equipment.is_equipped(Equipment.Slot.WEAPON), "武器槽已裝備")
	assert_eq(inv.instances().size(), 0, "背包實例扣除")

func test_activate_equipped_slot_unequips_back_to_inv():
	var m := _member()
	var inv := Inventory.new()   # 背包起始為空；下面直接裝備一把短劍，卸下後背包才會恰好 1 件實例
	m.equipment.equip(_sword_inst())
	var rows := CharacterItemsTab.rows(m, inv)
	# rows[0] = 武器槽（已裝 short_sword）
	var events := CharacterItemsTab.activate(rows[0], m, inv)
	assert_false(events.is_empty(), "卸下回傳事件")
	assert_false(m.equipment.is_equipped(Equipment.Slot.WEAPON), "武器槽已空")
	assert_eq(inv.instances().size(), 1, "回到背包（實例）")
