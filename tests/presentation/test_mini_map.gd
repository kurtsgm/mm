extends GutTest

const MiniMapScript := preload("res://presentation/ui/mini_map.gd")

func test_portal_overrides_tile_color():
	# portal 旗標優先於底層 tile
	assert_eq(MiniMapScript.tile_color(MapData.TileType.FLOOR, true), MiniMapScript.COL_PORTAL)
	assert_eq(MiniMapScript.tile_color(MapData.TileType.WALL, true), MiniMapScript.COL_PORTAL)

func test_tile_colors_by_type():
	assert_eq(MiniMapScript.tile_color(MapData.TileType.FLOOR, false), MiniMapScript.COL_FLOOR)
	assert_eq(MiniMapScript.tile_color(MapData.TileType.WALL, false), MiniMapScript.COL_WALL)
	assert_eq(MiniMapScript.tile_color(MapData.TileType.DOOR, false), MiniMapScript.COL_DOOR)
	assert_eq(MiniMapScript.tile_color(MapData.TileType.STAIRS_UP, false), MiniMapScript.COL_STAIRS_UP)
	assert_eq(MiniMapScript.tile_color(MapData.TileType.STAIRS_DOWN, false), MiniMapScript.COL_STAIRS_DOWN)

func test_panel_side_holds_full_window():
	var window_px := (2 * MiniMapScript.RADIUS + 1) * MiniMapScript.CELL_PX
	assert_eq(MiniMapScript.panel_side(), float(window_px + MiniMapScript.PAD * 2))

func test_cell_top_left_center_offset_is_radius_cells():
	var c := Vector2i(5, 5)
	var edge := MiniMapScript.PAD + MiniMapScript.RADIUS * MiniMapScript.CELL_PX
	assert_eq(MiniMapScript.cell_top_left(c, c), Vector2(edge, edge))

func test_cell_top_left_steps_by_cell_px():
	var c := Vector2i(2, 2)
	var a := MiniMapScript.cell_top_left(c, c)
	var b := MiniMapScript.cell_top_left(c + Vector2i(1, 1), c)
	assert_eq(b - a, Vector2(MiniMapScript.CELL_PX, MiniMapScript.CELL_PX))

func test_cell_top_left_depends_only_on_offset_from_center():
	# 相同「全域 - 中心」位移 → 相同像素（與絕對座標無關，含負座標鄰圖）
	assert_eq(MiniMapScript.cell_top_left(Vector2i(7, 3), Vector2i(5, 5)),
		MiniMapScript.cell_top_left(Vector2i(2, 8), Vector2i(0, 10)))

# --- 可互動節點標記 marker_color ---

func _chest(pos: Vector2i) -> Dictionary:
	return {"pos": pos, "items": [], "gold": 0, "model": "chest"}

func test_marker_chest_then_spent_when_opened():
	var m := MapData.new()
	m.objects = [_chest(Vector2i(1, 1))]
	assert_eq(MiniMapScript.marker_color(m, Vector2i(1, 1), [], []), MiniMapScript.COL_MARK_CHEST)
	assert_eq(MiniMapScript.marker_color(m, Vector2i(1, 1), [Vector2i(1, 1)], []), MiniMapScript.COL_MARK_SPENT)

func test_marker_vendor():
	var m := MapData.new()
	m.vendors = [{"pos": Vector2i(2, 2), "id": "shop"}]
	assert_eq(MiniMapScript.marker_color(m, Vector2i(2, 2), [], []), MiniMapScript.COL_MARK_VENDOR)

func test_marker_questgiver():
	var m := MapData.new()
	m.quest_givers = [{"pos": Vector2i(4, 1), "dialogue": "q"}]
	assert_eq(MiniMapScript.marker_color(m, Vector2i(4, 1), [], []), MiniMapScript.COL_MARK_QUEST)

func test_marker_scene_once_normal_then_spent_when_triggered():
	var m := MapData.new()
	m.scenes = [{"pos": Vector2i(3, 3), "dialogue": "d", "require": null, "once": true}]
	assert_eq(MiniMapScript.marker_color(m, Vector2i(3, 3), [], []), MiniMapScript.COL_MARK_SCENE)
	assert_eq(MiniMapScript.marker_color(m, Vector2i(3, 3), [], [Vector2i(3, 3)]), MiniMapScript.COL_MARK_SPENT)

func test_marker_scene_non_once_never_spent():
	var m := MapData.new()
	m.scenes = [{"pos": Vector2i(3, 3), "dialogue": "d", "require": null, "once": false}]
	assert_eq(MiniMapScript.marker_color(m, Vector2i(3, 3), [], [Vector2i(3, 3)]), MiniMapScript.COL_MARK_SCENE)

func test_marker_none_returns_null():
	assert_null(MiniMapScript.marker_color(MapData.new(), Vector2i(0, 0), [], []))

func test_marker_priority_questgiver_over_chest():
	var m := MapData.new()
	m.quest_givers = [{"pos": Vector2i(1, 1), "dialogue": "q"}]
	m.objects = [_chest(Vector2i(1, 1))]
	assert_eq(MiniMapScript.marker_color(m, Vector2i(1, 1), [], []), MiniMapScript.COL_MARK_QUEST)
