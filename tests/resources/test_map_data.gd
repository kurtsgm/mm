extends GutTest

func test_dimensions_and_get_tile():
	var map := MapData.new()
	map.width = 3
	map.height = 2
	map.tiles = PackedInt32Array([
		MapData.TileType.WALL, MapData.TileType.FLOOR, MapData.TileType.DOOR,
		MapData.TileType.FLOOR, MapData.TileType.STAIRS_UP, MapData.TileType.WALL,
	])
	assert_eq(map.width, 3)
	assert_eq(map.height, 2)
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(1, 0)), MapData.TileType.FLOOR)
	assert_eq(map.get_tile(Vector2i(2, 0)), MapData.TileType.DOOR)
	assert_eq(map.get_tile(Vector2i(1, 1)), MapData.TileType.STAIRS_UP)

func test_out_of_bounds_is_wall():
	var map := MapData.new()
	map.width = 2
	map.height = 2
	map.tiles = PackedInt32Array([0, 0, 0, 0])  # 全 FLOOR
	assert_eq(map.get_tile(Vector2i(-1, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(2, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(0, 2)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.FLOOR)

func test_encounters_accessors():
	var map := MapData.new()
	map.encounters = { Vector2i(2, 1): "g" }
	assert_true(map.has_encounter(Vector2i(2, 1)))
	assert_eq(map.get_encounter(Vector2i(2, 1)), "g")
	assert_false(map.has_encounter(Vector2i(0, 0)))
	assert_eq(map.get_encounter(Vector2i(0, 0)), "")
	map.clear_encounter(Vector2i(2, 1))
	assert_false(map.has_encounter(Vector2i(2, 1)))

func test_theme_id_defaults_to_default():
	var map := MapData.new()
	assert_eq(map.theme_id, "default")

func test_world_fields_default_empty():
	var map := MapData.new()
	assert_eq(map.display_name, "")
	assert_eq(map.neighbors, {})
	assert_eq(map.entries, {})
	assert_eq(map.links, {})

func test_neighbor_accessors():
	var map := MapData.new()
	map.neighbors = { GridDirection.Dir.EAST: "east_map" }
	assert_true(map.has_neighbor(GridDirection.Dir.EAST))
	assert_eq(map.get_neighbor(GridDirection.Dir.EAST), "east_map")
	assert_false(map.has_neighbor(GridDirection.Dir.WEST))
	assert_eq(map.get_neighbor(GridDirection.Dir.WEST), "")

func test_entry_accessors():
	var map := MapData.new()
	map.entries = { "gate": {"pos": Vector2i(2, 1), "facing": GridDirection.Dir.SOUTH} }
	assert_true(map.has_entry("gate"))
	assert_eq(map.get_entry("gate"), {"pos": Vector2i(2, 1), "facing": GridDirection.Dir.SOUTH})
	assert_false(map.has_entry("none"))
	assert_eq(map.get_entry("none"), {})

func test_link_accessors():
	var map := MapData.new()
	map.links = { Vector2i(3, 3): {"map": "town_oak", "entry": "gate"} }
	assert_true(map.has_link(Vector2i(3, 3)))
	assert_eq(map.get_link(Vector2i(3, 3)), {"map": "town_oak", "entry": "gate"})
	assert_false(map.has_link(Vector2i(0, 0)))
	assert_eq(map.get_link(Vector2i(0, 0)), {})

func test_quest_giver_accessors():
	var m := MapData.new()
	m.quest_givers = [{"pos": Vector2i(1, 1), "dialogue": "qg_x"}]
	assert_true(m.has_quest_giver(Vector2i(1, 1)))
	assert_false(m.has_quest_giver(Vector2i(0, 0)))
	assert_eq(m.get_quest_giver(Vector2i(1, 1))["dialogue"], "qg_x")
	assert_eq(m.get_quest_giver(Vector2i(0, 0)), {})
