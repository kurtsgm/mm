extends GutTest

# 傳一個 Dictionary，stringify 後交給 parse，讓測試精簡可讀。
func _p(d) -> MapData:
	return MapImporter.parse(JSON.stringify(d))

func test_parse_simple_grid():
	var m := _p({"grid": ["###", "#@.", "###"]})
	assert_not_null(m)
	assert_eq(m.width, 3)
	assert_eq(m.height, 3)
	assert_eq(m.start_pos, Vector2i(1, 1))
	assert_eq(m.start_facing, GridDirection.Dir.NORTH)
	assert_eq(m.get_tile(Vector2i(0, 0)), MapData.TileType.WALL)
	assert_eq(m.get_tile(Vector2i(1, 1)), MapData.TileType.FLOOR)
	assert_eq(m.get_tile(Vector2i(2, 1)), MapData.TileType.FLOOR)

func test_all_tile_types():
	var m := _p({"grid": ["@D<>"]})
	assert_not_null(m)
	assert_eq(m.get_tile(Vector2i(0, 0)), MapData.TileType.FLOOR)
	assert_eq(m.get_tile(Vector2i(1, 0)), MapData.TileType.DOOR)
	assert_eq(m.get_tile(Vector2i(2, 0)), MapData.TileType.STAIRS_UP)
	assert_eq(m.get_tile(Vector2i(3, 0)), MapData.TileType.STAIRS_DOWN)

func test_invalid_json_returns_null():
	assert_null(MapImporter.parse("{not json"))

func test_non_object_root_returns_null():
	assert_null(MapImporter.parse("[1, 2, 3]"))

func test_missing_grid_returns_null():
	assert_null(_p({"theme": "x"}))

func test_empty_grid_returns_null():
	assert_null(_p({"grid": []}))

func test_non_rectangular_returns_null():
	assert_null(_p({"grid": ["###", "#@", "###"]}))

func test_letters_in_grid_are_unknown_chars():
	# 字母不再是合法格子字元（怪物/連結改走 entities）
	assert_null(_p({"grid": ["@g"]}))
	assert_null(_p({"grid": ["@X"]}))

func test_missing_start_returns_null():
	assert_null(_p({"grid": ["###", "#.#", "###"]}))

func test_multiple_start_returns_null():
	assert_null(_p({"grid": ["@@"]}))

func test_theme_field_sets_theme_id():
	assert_eq(_p({"grid": ["@"], "theme": "castle"}).theme_id, "castle")

func test_missing_theme_defaults():
	assert_eq(_p({"grid": ["@"]}).theme_id, "default")

func test_empty_theme_defaults():
	assert_eq(_p({"grid": ["@"], "theme": ""}).theme_id, "default")

func test_name_field_sets_display_name():
	assert_eq(_p({"grid": ["@"], "name": "橡鎮"}).display_name, "橡鎮")

func test_neighbors_parsed():
	var m := _p({"grid": ["@"], "neighbors": {"north": "a", "east": "b", "south": "c", "west": "d"}})
	assert_eq(m.get_neighbor(GridDirection.Dir.NORTH), "a")
	assert_eq(m.get_neighbor(GridDirection.Dir.EAST), "b")
	assert_eq(m.get_neighbor(GridDirection.Dir.SOUTH), "c")
	assert_eq(m.get_neighbor(GridDirection.Dir.WEST), "d")

func test_entries_with_and_without_facing():
	var m := _p({"grid": ["#@#"], "entries": {"gate": {"pos": [1, 0], "facing": "S"}, "spot": {"pos": [0, 0]}}})
	assert_eq(m.get_entry("gate"), {"pos": Vector2i(1, 0), "facing": GridDirection.Dir.SOUTH})
	assert_eq(m.get_entry("spot"), {"pos": Vector2i(0, 0), "facing": GridDirection.Dir.NORTH})

func test_at_creates_start_entry():
	assert_eq(_p({"grid": ["#@#"]}).get_entry("start"), {"pos": Vector2i(1, 0), "facing": GridDirection.Dir.NORTH})

func test_monster_entity_becomes_encounter():
	var m := _p({"grid": ["#@.", "..."], "entities": [{"type": "monster", "pos": [2, 0], "encounter": "g"}]})
	assert_not_null(m)
	assert_eq(m.get_tile(Vector2i(2, 0)), MapData.TileType.FLOOR)
	assert_true(m.has_encounter(Vector2i(2, 0)))
	assert_eq(m.get_encounter(Vector2i(2, 0)), "g")

func test_multiple_monsters():
	var m := _p({"grid": ["@..", "..."], "entities": [
		{"type": "monster", "pos": [1, 0], "encounter": "g"},
		{"type": "monster", "pos": [2, 1], "encounter": "o"}]})
	assert_eq(m.get_encounter(Vector2i(1, 0)), "g")
	assert_eq(m.get_encounter(Vector2i(2, 1)), "o")

func test_portal_entity_with_entry():
	var m := _p({"grid": ["@."], "entities": [{"type": "portal", "pos": [1, 0], "to": "town_oak", "entry": "gate"}]})
	assert_true(m.has_link(Vector2i(1, 0)))
	assert_eq(m.get_link(Vector2i(1, 0)), {"map": "town_oak", "entry": "gate"})

func test_portal_without_entry_defaults_start():
	var m := _p({"grid": ["@."], "entities": [{"type": "portal", "pos": [1, 0], "to": "town_oak"}]})
	assert_eq(m.get_link(Vector2i(1, 0)), {"map": "town_oak", "entry": "start"})

func test_unknown_entity_type_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [{"type": "chest", "pos": [1, 0]}]}))

func test_entity_missing_pos_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [{"type": "monster", "encounter": "g"}]}))

func test_entity_missing_required_field_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [{"type": "monster", "pos": [1, 0]}]}))
	assert_null(_p({"grid": ["@."], "entities": [{"type": "portal", "pos": [1, 0]}]}))

func test_entity_pos_out_of_bounds_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [{"type": "monster", "pos": [5, 5], "encounter": "g"}]}))

func test_pos_accepts_json_float_numbers():
	# JSON 數字可能解析成 float；座標需正確轉 int
	var m := MapImporter.parse('{"grid":["@."],"entities":[{"type":"monster","pos":[1.0,0.0],"encounter":"g"}]}')
	assert_not_null(m)
	assert_true(m.has_encounter(Vector2i(1, 0)))

func test_minimal_map_has_empty_world_fields():
	var m := _p({"grid": ["@"]})
	assert_eq(m.neighbors, {})
	assert_eq(m.links, {})
	assert_eq(m.encounters, {})
	assert_eq(m.display_name, "")
