extends GutTest

const MapManagerScript := preload("res://autoload/map_manager.gd")

func test_load_text_sets_current_map_and_grid():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.load_text("###\n#@#\n###")
	assert_not_null(map)
	assert_eq(mm.current_map, map)
	assert_eq(mm.current_grid.width, 3)
	assert_eq(mm.current_grid.height, 3)
	assert_true(mm.current_grid.is_solid(Vector2i(0, 0)))
	assert_true(mm.current_grid.is_walkable(Vector2i(1, 1)))
