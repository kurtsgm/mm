extends GutTest

func test_parse_simple_map():
	var map := MapAsciiImporter.parse("###\n#@.\n###")
	assert_not_null(map)
	assert_eq(map.width, 3)
	assert_eq(map.height, 3)
	assert_eq(map.start_pos, Vector2i(1, 1))
	assert_eq(map.start_facing, GridDirection.Dir.NORTH)
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(1, 1)), MapData.TileType.FLOOR)  # @ 是地板
	assert_eq(map.get_tile(Vector2i(2, 1)), MapData.TileType.FLOOR)

func test_parse_all_tile_types():
	var map := MapAsciiImporter.parse("@D<>")
	assert_not_null(map)
	assert_eq(map.width, 4)
	assert_eq(map.height, 1)
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.FLOOR)
	assert_eq(map.get_tile(Vector2i(1, 0)), MapData.TileType.DOOR)
	assert_eq(map.get_tile(Vector2i(2, 0)), MapData.TileType.STAIRS_UP)
	assert_eq(map.get_tile(Vector2i(3, 0)), MapData.TileType.STAIRS_DOWN)

func test_trims_trailing_blank_lines_and_whitespace():
	# 開頭空行要丟掉；"#@  " 行尾空白要修掉 → 寬度 2
	var map := MapAsciiImporter.parse("\n##\n#@  \n##\n\n")
	assert_not_null(map)
	assert_eq(map.width, 2)
	assert_eq(map.height, 3)
	assert_eq(map.start_pos, Vector2i(1, 1))

func test_non_rectangular_returns_null():
	assert_null(MapAsciiImporter.parse("###\n#@\n###"))

func test_unknown_char_returns_null():
	assert_null(MapAsciiImporter.parse("@X"))

func test_missing_start_returns_null():
	assert_null(MapAsciiImporter.parse("###\n#.#\n###"))

func test_multiple_start_returns_null():
	assert_null(MapAsciiImporter.parse("@@"))

func test_parses_monster_marker_as_floor_with_encounter():
	var map := MapAsciiImporter.parse("###\n#@g\n###")
	assert_not_null(map)
	assert_eq(map.get_tile(Vector2i(2, 1)), MapData.TileType.FLOOR)
	assert_true(map.has_encounter(Vector2i(2, 1)))
	assert_eq(map.get_encounter(Vector2i(2, 1)), "g")
	assert_false(map.has_encounter(Vector2i(1, 1)))  # @ 不是遭遇

func test_multiple_markers_recorded():
	var map := MapAsciiImporter.parse("#####\n#@g.o\n#####")
	assert_not_null(map)
	assert_eq(map.get_encounter(Vector2i(2, 1)), "g")
	assert_eq(map.get_encounter(Vector2i(4, 1)), "o")
	assert_eq(map.get_tile(Vector2i(2, 1)), MapData.TileType.FLOOR)
	assert_eq(map.get_tile(Vector2i(4, 1)), MapData.TileType.FLOOR)

func test_theme_header_sets_theme_id():
	var map := MapAsciiImporter.parse("theme: castle\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.theme_id, "castle")
	assert_eq(map.start_pos, Vector2i(1, 1))
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.WALL)

func test_no_header_defaults_theme_id():
	var map := MapAsciiImporter.parse("###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.theme_id, "default")

func test_unknown_directive_ignored():
	var map := MapAsciiImporter.parse("name: dungeon\ntheme: cave\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.theme_id, "cave")
	assert_eq(map.width, 3)
	assert_eq(map.height, 3)

func test_empty_theme_value_keeps_default():
	var map := MapAsciiImporter.parse("theme:\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.theme_id, "default")

func test_header_then_encounter_still_parses():
	var map := MapAsciiImporter.parse("theme: cave\n###\n#@g\n###")
	assert_not_null(map)
	assert_eq(map.theme_id, "cave")
	assert_true(map.has_encounter(Vector2i(2, 1)))
	assert_eq(map.start_pos, Vector2i(1, 1))

func test_name_header_sets_display_name():
	var map := MapAsciiImporter.parse("name: 橡鎮\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.display_name, "橡鎮")

func test_neighbor_headers_parsed():
	var map := MapAsciiImporter.parse("north: a\neast: b\nsouth: c\nwest: d\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.get_neighbor(GridDirection.Dir.NORTH), "a")
	assert_eq(map.get_neighbor(GridDirection.Dir.EAST), "b")
	assert_eq(map.get_neighbor(GridDirection.Dir.SOUTH), "c")
	assert_eq(map.get_neighbor(GridDirection.Dir.WEST), "d")

func test_entry_header_with_facing():
	var map := MapAsciiImporter.parse("entry gate: 1,1 S\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.get_entry("gate"), {"pos": Vector2i(1, 1), "facing": GridDirection.Dir.SOUTH})

func test_entry_header_defaults_facing_north():
	var map := MapAsciiImporter.parse("entry spot: 2,0\n###\n#@#\n###")
	assert_eq(map.get_entry("spot"), {"pos": Vector2i(2, 0), "facing": GridDirection.Dir.NORTH})

func test_at_creates_start_entry():
	var map := MapAsciiImporter.parse("###\n#@#\n###")
	assert_eq(map.get_entry("start"), {"pos": Vector2i(1, 1), "facing": GridDirection.Dir.NORTH})

func test_link_marker_is_floor_and_recorded():
	var map := MapAsciiImporter.parse("link T: town_oak.gate\n###\n#@T\n###")
	assert_not_null(map)
	assert_eq(map.get_tile(Vector2i(2, 1)), MapData.TileType.FLOOR)
	assert_true(map.has_link(Vector2i(2, 1)))
	assert_eq(map.get_link(Vector2i(2, 1)), {"map": "town_oak", "entry": "gate"})

func test_link_value_without_entry_defaults_start():
	var map := MapAsciiImporter.parse("link T: town_oak\n###\n#@T\n###")
	assert_eq(map.get_link(Vector2i(2, 1)), {"map": "town_oak", "entry": "start"})

func test_uppercase_without_link_declaration_returns_null():
	# 'Z' 無對應 link 宣告 → 未知字元 → null（嚴格抓打字錯）
	assert_null(MapAsciiImporter.parse("##\n@Z"))

func test_old_map_has_empty_world_fields():
	var map := MapAsciiImporter.parse("###\n#@#\n###")
	assert_eq(map.neighbors, {})
	assert_eq(map.links, {})
	assert_eq(map.display_name, "")
