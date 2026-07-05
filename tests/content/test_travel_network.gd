extends GutTest

func _load_map(id: String) -> MapData:
	var f := FileAccess.open("res://content/maps/%s.json" % id, FileAccess.READ)
	return MapImporter.parse(f.get_as_text())

func test_nodes_reference_existing_maps_and_entries() -> void:
	var seen := {}
	for n in TravelCatalog.load_network():
		var id := String(n["id"])
		assert_false(seen.has(id), "node id 重複: " + id)
		seen[id] = true
		var m := _load_map(String(n["map"]))
		assert_not_null(m, "map 不存在: " + String(n["map"]))
		assert_true(m.has_entry(String(n["entry"])), "entry 不存在: " + String(n["entry"]))

func test_travel_tiles_reference_known_nodes() -> void:
	var known := {}
	for n in TravelCatalog.load_network():
		known[String(n["id"])] = true
	for path in DirAccess.get_files_at("res://content/maps"):
		if not path.ends_with(".json"):
			continue
		var m := _load_map(path.trim_suffix(".json"))
		for t in m.travels:
			assert_true(known.has(String(t["node"])), "未知 travel node: " + String(t["node"]))
