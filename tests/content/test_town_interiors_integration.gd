extends GutTest

# 整合：城鎮每棟「可進入建築」與它的室內地圖要形成完整來回閉環。
# 守住：外觀模型解析 / 室內存在且 10×10 / 室內出口連回 town 的衍生入口 / 室內有 from_town。

func _parse(path: String) -> MapData:
	return MapImporter.parse(FileAccess.get_file_as_string(path))

func test_every_town_building_round_trips_with_its_interior():
	var town := _parse("res://content/maps/town_oak.json")
	assert_not_null(town)
	var checked := 0
	for b in town.buildings:
		# 外觀模型（若有）要能解析
		if String(b["model"]) != "":
			assert_true(DecorationCatalog.has_model(String(b["model"])),
				"建築 %s 的外觀 %s 應可解析" % [b["id"], b["model"]])
		var interior_id: String = String(b["interior"])
		if interior_id == "":
			continue   # 純裝飾結構（水井）無室內
		var out_entry: String = String(b["id"]) + "_out"
		assert_true(town.has_entry(out_entry), "town 應有回程入口 %s" % out_entry)
		var inner := _parse("res://content/maps/%s.json" % interior_id)
		assert_not_null(inner, "室內 %s 應可載入" % interior_id)
		if inner == null:
			continue
		assert_eq(inner.width, 10, "%s 寬應為 10" % interior_id)
		assert_eq(inner.height, 10, "%s 高應為 10" % interior_id)
		assert_true(inner.has_entry("from_town"), "%s 應有 from_town 入口" % interior_id)
		var found_back := false
		for cell in inner.links:
			var lk = inner.links[cell]
			if lk["map"] == "town_oak" and lk["entry"] == out_entry:
				found_back = true
		assert_true(found_back, "%s 應有出口連回 town_oak 的 %s" % [interior_id, out_entry])
		checked += 1
	assert_eq(checked, 5, "橡鎮應有 5 間可進入的店各自閉環")
