extends GutTest

func test_load_goods():
	var v := VendorCatalog.load_vendor("oak_general_store")
	assert_eq(v["kind"], "goods")
	assert_true(v["stock"].has("potion"))

func test_load_spells():
	var v := VendorCatalog.load_vendor("oak_mage")
	assert_eq(v["kind"], "spells")
	assert_eq(v["spells"].size(), 3)

func test_load_services():
	var v := VendorCatalog.load_vendor("oak_temple")
	assert_eq(v["kind"], "services")
	assert_eq(v["offers"][0]["effect"], "revive")

func test_missing_returns_empty():
	assert_true(VendorCatalog.load_vendor("nope_does_not_exist").is_empty())

func test_sold_spells_have_gold_cost():
	assert_eq(SpellBook.get_spell("spark").gold_cost, 80)
	assert_eq(SpellBook.get_spell("bless").gold_cost, 60)
