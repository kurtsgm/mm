extends GutTest

func test_goblin_menace_loads():
	var d := QuestCatalog.load_quest("goblin_menace")
	assert_not_null(d)
	assert_eq(d.stage_count(), 4)
	assert_eq(d.stage(0)["type"], "kill")
	assert_eq(d.stage(1)["type"], "collect")
	assert_eq(d.stage(2)["type"], "reach")
	assert_eq(d.stage(3)["type"], "talk")

func test_qg_oak_guard_dialogue_loads():
	assert_not_null(DialogueCatalog.load_dialogue("qg_oak_guard"))

func test_town_oak_has_questgiver():
	var map := MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/town_oak.json"))
	assert_not_null(map)
	assert_true(map.has_quest_giver(Vector2i(2, 1)))

func test_wild_ne_has_goblin_and_chest():
	var map := MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/wild_ne.json"))
	assert_not_null(map)
	assert_eq(map.get_encounter(Vector2i(1, 1)), "g")
	assert_true(map.has_object(Vector2i(3, 1)))
	assert_eq(map.get_object(Vector2i(3, 1))["items"], ["lucky_charm"])
