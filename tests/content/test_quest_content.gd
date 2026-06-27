extends GutTest

func test_goblin_menace_loads():
	var d := QuestCatalog.load_quest("goblin_menace")
	assert_not_null(d)
	assert_eq(d.stage_count(), 4)
	assert_eq(d.stage(0)["type"], "kill")
	assert_eq(d.stage(1)["type"], "collect")
	assert_eq(d.stage(2)["type"], "reach")
	assert_eq(d.stage(3)["type"], "talk")
	# kill 目標＝野外遇抵 uid，且非城鎮遇抵 uid（不會被城鎮哥布林滿足）
	var ne := MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/wild_ne.json"))
	var oak := MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/town_oak.json"))
	var wild_uid := ne.get_encounter_uid(Vector2i(1, 1))
	assert_eq(d.stage(0)["targets"], [wild_uid])
	assert_ne(wild_uid, oak.get_encounter_uid(Vector2i(3, 1)))
	assert_ne(wild_uid, "")

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

# --- 多 NPC demo 任務 wild_message（A 發@wild_nw、B 交@wild_ne）---

func test_wild_message_quest_loads():
	var d := QuestCatalog.load_quest("wild_message")
	assert_not_null(d)
	assert_eq(d.stage_count(), 1)
	assert_eq(d.stage(0)["type"], "talk")
	assert_eq(d.rewards["xp"], 30)
	assert_eq(d.rewards["gold"], 40)

func test_messenger_and_scout_dialogues_load():
	assert_not_null(DialogueCatalog.load_dialogue("qg_nw_messenger"))
	assert_not_null(DialogueCatalog.load_dialogue("qg_ne_scout"))

func test_giver_A_in_wild_nw_and_turnin_B_in_wild_ne():
	var nw := MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/wild_nw.json"))
	assert_not_null(nw)
	assert_true(nw.has_quest_giver(Vector2i(1, 2)))
	assert_eq(nw.get_quest_giver(Vector2i(1, 2))["dialogue"], "qg_nw_messenger")
	var ne := MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/wild_ne.json"))
	assert_not_null(ne)
	assert_true(ne.has_quest_giver(Vector2i(1, 3)))
	assert_eq(ne.get_quest_giver(Vector2i(1, 3))["dialogue"], "qg_ne_scout")
