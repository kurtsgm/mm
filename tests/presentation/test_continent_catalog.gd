extends GutTest

func test_loads_six_continents() -> void:
	assert_eq(ContinentCatalog.load_all().size(), 6)

func test_find_by_id() -> void:
	assert_eq(String(ContinentCatalog.find("oak")["name"]), "橡境")
	assert_true(ContinentCatalog.find("nope").is_empty())
