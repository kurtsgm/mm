extends GutTest

func _load() -> MapData:
	return MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/int_oak_general.json"))

func test_interior_loads_10x10():
	var m := _load()
	assert_not_null(m)
	assert_eq(m.width, 10)
	assert_eq(m.height, 10)

func test_vendor_at_counter():
	var m := _load()
	assert_true(m.has_vendor(Vector2i(4, 3)))
	assert_eq(m.get_vendor(Vector2i(4, 3))["id"], "oak_general_store")

func test_exit_links_back_to_town():
	var m := _load()
	assert_eq(m.get_link(Vector2i(4, 8)), {"map": "town_oak", "entry": "oak_general_store_out"})
	assert_eq(m.get_entry("from_town"), {"pos": Vector2i(4, 7), "facing": GridDirection.Dir.NORTH})

func test_has_decorations():
	assert_gt(_load().decorations.size(), 2)
