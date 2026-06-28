extends GutTest

func _data() -> SaveData:
	var d := SaveData.new()
	d.party = Party.new()
	d.inventory = Inventory.new()
	d.quests = {"q": {"status": "active", "stage": 1}}
	d.defeated_encounters = {"u-a": true, "u-b": true}
	d.tracked_quest = "q"
	return d

func test_quests_round_trip():
	var raw := SaveSerializer.to_dict(_data())
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.quests["q"]["status"], "active")
	assert_eq(back.quests["q"]["stage"], 1)
	assert_false(back.quests["q"].has("count"))   # 已移除 count

func test_quests_absent_is_empty():
	var raw := SaveSerializer.to_dict(_data())
	raw["state"].erase("quests")
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.quests, {})

func test_defeated_encounters_round_trip():
	var raw := SaveSerializer.to_dict(_data())
	var back := SaveSerializer.from_dict(raw)
	assert_true(back.defeated_encounters.has("u-a"))
	assert_true(back.defeated_encounters.has("u-b"))

func test_defeated_encounters_absent_is_empty():
	var raw := SaveSerializer.to_dict(_data())
	raw["state"].erase("defeated_encounters")
	assert_eq(SaveSerializer.from_dict(raw).defeated_encounters, {})

func test_tracked_quest_round_trip():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_data()))
	assert_eq(back.tracked_quest, "q")

func test_tracked_quest_absent_is_empty():
	var raw := SaveSerializer.to_dict(_data())
	raw["state"].erase("tracked_quest")
	assert_eq(SaveSerializer.from_dict(raw).tracked_quest, "")

func test_version_is_11():
	assert_eq(SaveSerializer.to_dict(_data())["version"], 11)

func test_old_version_rejected():
	var raw := SaveSerializer.to_dict(_data())
	raw["version"] = 9
	assert_null(SaveSerializer.from_dict(raw), "舊版不再接受（只收 v11）")
