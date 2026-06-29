extends GutTest

# `building` entity：多格佔地建築 primitive。
# rect 全部蓋成 WALL、門那格留 FLOOR（walkable）、門→室內 link、衍生 <id>_out 回程入口、
# 選擇性 model 裝飾；無 door/interior = 純實心裝飾結構（紀念碑/水井）。

func _p(d) -> MapData:
	return MapImporter.parse(JSON.stringify(d))

# 5×5 全地板、@ 在 (0,0)，方便在中段擺建築。
const G5 := ["@....", ".....", ".....", ".....", "....."]

func _shop(extra := {}) -> Dictionary:
	var b := {"type": "building", "id": "b", "rect": [1, 1, 2, 2], "door": [2, 2],
		"facing": "S", "interior": "int_b", "model": "m_b"}
	for k in extra:
		b[k] = extra[k]
	return b

# --- footprint 蓋牆、門格留地板 ---

func test_building_stamps_footprint_walls_and_door_floor():
	var m := _p({"grid": G5, "entities": [_shop()]})
	assert_not_null(m)
	assert_eq(m.get_tile(Vector2i(1, 1)), MapData.TileType.WALL)
	assert_eq(m.get_tile(Vector2i(2, 1)), MapData.TileType.WALL)
	assert_eq(m.get_tile(Vector2i(1, 2)), MapData.TileType.WALL)
	assert_eq(m.get_tile(Vector2i(2, 2)), MapData.TileType.FLOOR, "門那格必須 walkable")

# --- 門連到室內 ---

func test_building_door_links_interior_default_entry():
	var m := _p({"grid": G5, "entities": [_shop()]})
	assert_true(m.has_link(Vector2i(2, 2)))
	assert_eq(m.get_link(Vector2i(2, 2)), {"map": "int_b", "entry": "from_town"})

func test_building_explicit_entry_honored():
	var m := _p({"grid": G5, "entities": [_shop({"entry": "side"})]})
	assert_eq(m.get_link(Vector2i(2, 2))["entry"], "side")

# --- 衍生回程入口 <id>_out 在門前一格、朝 facing ---

func test_building_derived_out_entry():
	var m := _p({"grid": G5, "entities": [_shop()]})  # door (2,2) facing S → front (2,3)
	assert_true(m.has_entry("b_out"))
	assert_eq(m.get_entry("b_out"), {"pos": Vector2i(2, 3), "facing": GridDirection.Dir.SOUTH})

# --- 外觀模型（選擇性）擺在 rect 左上格、不旋轉（facing N）---

func test_building_decoration_added_at_anchor():
	var m := _p({"grid": G5, "entities": [_shop()]})
	assert_eq(m.decorations.size(), 1)
	var d = m.decorations[0]
	assert_eq(d["pos"], Vector2i(1, 1))
	assert_eq(d["model"], "m_b")
	assert_eq(d["facing"], GridDirection.Dir.NORTH, "模型自帶門向，不靠 decoration 旋轉")
	assert_eq(d["scale"], 1.0)

func test_building_without_model_adds_no_decoration():
	var b := _shop()
	b.erase("model")
	var m := _p({"grid": G5, "entities": [b]})
	assert_eq(m.decorations.size(), 0)

# --- 記錄到 MapData.buildings（給測試/未來 minimap）---

func test_building_recorded_in_buildings_array():
	var m := _p({"grid": G5, "entities": [_shop()]})
	assert_eq(m.buildings.size(), 1)
	var rec = m.buildings[0]
	assert_eq(rec["id"], "b")
	assert_eq(rec["rect"], [1, 1, 2, 2])
	assert_eq(rec["door"], Vector2i(2, 2))
	assert_eq(rec["interior"], "int_b")

# --- 純實心結構（無 door/interior）= 紀念碑/水井 ---

func test_solid_building_all_walls_no_link_no_out_entry():
	var m := _p({"grid": G5, "entities": [
		{"type": "building", "id": "well", "rect": [2, 2, 1, 1], "model": "oak_well"}]})
	assert_not_null(m)
	assert_eq(m.get_tile(Vector2i(2, 2)), MapData.TileType.WALL)
	assert_false(m.has_link(Vector2i(2, 2)))
	assert_false(m.has_entry("well_out"))
	assert_eq(m.decorations.size(), 1)
	assert_eq(m.buildings.size(), 1)

# --- building 不需要 pos 欄位（繞過通用 pos 檢查）---

func test_building_does_not_require_pos_field():
	assert_not_null(_p({"grid": G5, "entities": [_shop()]}))

# --- 容錯：違規 → null ---

func test_building_missing_id_rejected():
	var b := _shop()
	b.erase("id")
	assert_null(_p({"grid": G5, "entities": [b]}))

func test_building_missing_rect_rejected():
	var b := _shop()
	b.erase("rect")
	assert_null(_p({"grid": G5, "entities": [b]}))

func test_building_rect_out_of_bounds_rejected():
	assert_null(_p({"grid": G5, "entities": [_shop({"rect": [3, 3, 5, 5]})]}))

func test_building_door_not_in_rect_rejected():
	assert_null(_p({"grid": G5, "entities": [_shop({"door": [0, 0]})]}))

func test_building_door_without_interior_rejected():
	var b := _shop()
	b.erase("interior")
	assert_null(_p({"grid": G5, "entities": [b]}))

func test_building_front_out_of_bounds_rejected():
	# rect 在右下角、門朝外指出界 → front OOB → null
	assert_null(_p({"grid": G5, "entities": [
		{"type": "building", "id": "edge", "rect": [4, 4, 1, 1], "door": [4, 4],
			"facing": "S", "interior": "x"}]}))

func test_no_buildings_means_empty_array():
	assert_eq(_p({"grid": G5}).buildings, [])
