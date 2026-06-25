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
