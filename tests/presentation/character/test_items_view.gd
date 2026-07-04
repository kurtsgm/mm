extends GutTest

func before_all():
	# 背包裝備實例需 base_resolver 解析 base_def。
	ItemCatalog.install_resolver()

func after_all():
	ItemInstance.base_resolver = Callable()

func _member() -> Character:
	var c := Character.new()
	c.name = "亞爾"
	c.char_class = "Knight"
	return c

func _inv(pairs: Dictionary) -> Inventory:
	var inv := Inventory.new()
	for id in pairs:
		inv.add(id, int(pairs[id]))
	return inv

func _view(rows: Array, active: int) -> CharacterItemsView:
	var v := CharacterItemsView.new()
	add_child_autofree(v)
	v.refresh(rows, active)
	return v

func test_renders_three_equip_and_n_bag_rows():
	var rows := CharacterItemsTab.rows(_member(), _inv({"potion": 2, "short_sword": 1}))
	var v := _view(rows, 0)
	assert_eq(v.equip_count(), 3, "三個裝備槽")
	assert_eq(v.bag_count(), 2, "兩種背包道具")

func test_renders_equipment_instance_in_bag():
	# 背包裝備實例（inst 列，無 id）也應被算進背包並渲染。
	var inv := Inventory.new()
	var it := ItemInstance.new(); it.base_id = "short_sword"
	inv.add_instance(it)
	var rows := CharacterItemsTab.rows(_member(), inv)
	var v := _view(rows, 3)
	assert_eq(v.equip_count(), 3, "三個裝備槽")
	assert_eq(v.bag_count(), 1, "背包含一件裝備實例")
	assert_true(v.active_in_bag(), "作用列在背包欄")

func test_empty_bag_shows_placeholder():
	var rows := CharacterItemsTab.rows(_member(), _inv({}))
	var v := _view(rows, 0)
	assert_eq(v.bag_count(), 0, "背包無道具")
	assert_true(v.has_empty_placeholder(), "背包空顯示（空）佔位")

func test_active_index_in_bag_zone():
	var rows := CharacterItemsTab.rows(_member(), _inv({"potion": 2}))
	var v := _view(rows, 3)  # rows[0..2]=裝備槽, rows[3]=第一個背包列
	assert_eq(v.active_index(), 3)
	assert_true(v.active_in_bag(), "作用列在背包欄")

func test_active_index_in_equip_zone():
	var rows := CharacterItemsTab.rows(_member(), _inv({"potion": 2}))
	var v := _view(rows, 0)
	assert_false(v.active_in_bag(), "作用列在裝備欄")

func test_category_label_mapping():
	assert_eq(CharacterItemsView.category_label(ItemDef.Category.WEAPON), "武")
	assert_eq(CharacterItemsView.category_label(ItemDef.Category.ARMOR), "甲")
	assert_eq(CharacterItemsView.category_label(ItemDef.Category.ACCESSORY), "飾")
	assert_eq(CharacterItemsView.category_label(ItemDef.Category.CONSUMABLE), "用")

# 品質色名：rows() 應在裝備列（已裝備槽 / 背包裝備實例）帶 quality，消耗品列不帶。
func test_rows_puts_quality_on_equipped_instance_row():
	var m := _member()
	var it := ItemInstance.new(); it.base_id = "short_sword"; it.quality = Quality.Q.RARE
	m.equipment.equip(it)
	var rows := CharacterItemsTab.rows(m, _inv({}))
	var wr: Dictionary = {}
	for r in rows:
		if String(r.get("kind", "")) == "equip" and int(r.get("slot", -1)) == Equipment.Slot.WEAPON:
			wr = r
	assert_true(wr.has("quality"), "已裝備武器列帶 quality")
	assert_eq(int(wr["quality"]), Quality.Q.RARE)

func test_rows_puts_quality_on_bag_instance_row():
	var inv := Inventory.new()
	var it := ItemInstance.new(); it.base_id = "short_sword"; it.quality = Quality.Q.FINE
	inv.add_instance(it)
	var rows := CharacterItemsTab.rows(_member(), inv)
	var br: Dictionary = {}
	for r in rows:
		if r.has("inst"):
			br = r
	assert_true(br.has("quality"), "背包裝備實例列帶 quality")
	assert_eq(int(br["quality"]), Quality.Q.FINE)

func test_rows_no_quality_on_consumable_row():
	var rows := CharacterItemsTab.rows(_member(), _inv({"potion": 2}))
	var cr: Dictionary = {}
	for r in rows:
		if String(r.get("kind", "")) == "item" and r.has("id"):
			cr = r
	assert_false(cr.is_empty(), "有消耗品列")
	assert_false(cr.has("quality"), "消耗品列不帶 quality")

func test_name_color_uses_quality_color_when_present():
	var v := CharacterItemsView.new()
	add_child_autofree(v)
	assert_eq(v._name_color({"quality": Quality.Q.RARE}), Quality.color(Quality.Q.RARE), "帶 quality 用品質色")
	assert_eq(v._name_color({}), PanelSkin.TEXT, "無 quality 退回 TEXT")
