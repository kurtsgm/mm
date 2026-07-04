extends GutTest

func test_unknown_id_returns_null():
	assert_false(ItemCatalog.has_item("nope"))
	assert_null(ItemCatalog.get_item("nope"))

func test_loads_short_sword_with_fields():
	var sword := ItemCatalog.get_item("short_sword")
	assert_not_null(sword)
	assert_eq(sword.id, "short_sword")
	assert_eq(sword.category, ItemDef.Category.WEAPON)
	assert_eq(sword.attack, 6)

func test_loads_potion_consumable():
	var potion := ItemCatalog.get_item("potion")
	assert_not_null(potion)
	assert_eq(potion.category, ItemDef.Category.CONSUMABLE)
	assert_eq(potion.heal_hp, 15)
	assert_true(potion.stackable)

func test_loads_revive_herb():
	var herb := ItemCatalog.get_item("revive")
	assert_not_null(herb)
	assert_true(herb.revive)

func test_all_ids_load():
	var ids := ItemCatalog.all_ids()
	assert_true(ids.size() >= 6)
	for id in ids:
		assert_not_null(ItemCatalog.get_item(id), "id %s 應可載入" % id)

func test_unique_base_ids_exist():
	for uid in UniqueCatalog.eligible(100):
		var base_id: String = String(UniqueCatalog.entry(uid)["base_id"])
		assert_true(ItemCatalog.has_item(base_id), "unique base 必須存在：%s" % base_id)

func test_loot_pool_nonempty_and_all_droppable():
	var bases := LootPool.equipment_bases()
	assert_true(bases.size() >= 10)
	for d in bases:
		assert_true(d.drop_weight > 0)
