extends GutTest

func _map(text: String) -> MapData:
	return MapAsciiImporter.parse(text)

func test_builds_floor_plus_one_box_per_nonfloor_tile():
	# 3x3 外圈牆、中央 @ 地板 → 非地板 8 格
	var wb := WorldBuilder.new()
	add_child_autofree(wb)
	wb.build(_map("###\n#@#\n###"))
	assert_eq(wb.get_child_count(), 8 + 1, "1 floor + 8 wall boxes")

func test_door_and_stairs_each_add_one_box():
	var wb := WorldBuilder.new()
	add_child_autofree(wb)
	wb.build(_map("@D<>"))  # floor, door, stairs_up, stairs_down → 非地板 3
	assert_eq(wb.get_child_count(), 3 + 1, "door+up+down = 3 boxes + 1 floor")

func test_rebuild_clears_previous_geometry():
	var wb := WorldBuilder.new()
	add_child_autofree(wb)
	wb.build(_map("###\n#@#\n###"))     # 1 floor + 8 walls
	assert_eq(wb.get_child_count(), 9)
	wb.build(_map("...\n.@.\n..."))     # 全地板 → 0 牆
	assert_eq(wb.get_child_count(), 1, "rebuild 必須同步清掉舊方塊，只剩地板")
