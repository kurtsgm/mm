extends GutTest

func _load() -> MapData:
	return MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/int_oak_inn.json"))

func test_interior_loads_16x16():
	var m := _load()
	assert_not_null(m)
	assert_eq(m.width, 16)
	assert_eq(m.height, 16)

func test_vendor_at_counter():
	var m := _load()
	assert_true(m.has_vendor(Vector2i(7, 6)))
	assert_eq(m.get_vendor(Vector2i(7, 6))["id"], "oak_inn")

func test_exit_links_back_to_town():
	var m := _load()
	assert_eq(m.get_link(Vector2i(7, 11)), {"map": "town_oak", "entry": "oak_inn_out"})
	assert_eq(m.get_entry("from_town"), {"pos": Vector2i(7, 10), "facing": GridDirection.Dir.NORTH})

func test_has_decorations():
	assert_gt(_load().decorations.size(), 2)
