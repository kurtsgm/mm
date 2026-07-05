extends GutTest

func test_registry_rects_are_ratio_coords() -> void:
	for c in ContinentCatalog.load_all():
		var r: Array = c["rect"]
		assert_eq(r.size(), 4)
		for v in r:
			assert_between(float(v), 0.0, 1.0)

func test_every_map_tagged_with_known_continent() -> void:
	var known := {}
	for c in ContinentCatalog.load_all():
		known[String(c["id"])] = true
	for path in DirAccess.get_files_at("res://content/maps"):
		if not path.ends_with(".json"):
			continue
		var f := FileAccess.open("res://content/maps/" + path, FileAccess.READ)
		var m := MapImporter.parse(f.get_as_text())
		assert_ne(m.continent, "", path + " 缺 continent")
		assert_true(known.has(m.continent), path + " continent 未註冊")

func test_travel_nodes_use_known_continents() -> void:
	var known := {}
	for c in ContinentCatalog.load_all():
		known[String(c["id"])] = true
	for n in TravelCatalog.load_network():
		assert_true(known.has(String(n["continent"])))
