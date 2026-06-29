extends GutTest

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
