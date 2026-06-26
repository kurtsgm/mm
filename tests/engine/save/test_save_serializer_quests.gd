extends GutTest

func _data() -> SaveData:
	var d := SaveData.new()
	d.party = Party.new()
	d.inventory = Inventory.new()
	d.quests = {"q": {"status": "active", "stage": 1, "count": 2}}
	return d

func test_quests_round_trip():
	var raw := SaveSerializer.to_dict(_data())
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.quests["q"]["status"], "active")
	assert_eq(back.quests["q"]["stage"], 1)
	assert_eq(back.quests["q"]["count"], 2)

func test_quests_absent_is_empty():
	var raw := SaveSerializer.to_dict(_data())
	raw["state"].erase("quests")
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.quests, {})

func test_version_is_6():
	assert_eq(SaveSerializer.to_dict(_data())["version"], 6)

func test_old_version_rejected():
	var raw := SaveSerializer.to_dict(_data())
	raw["version"] = 5
	assert_null(SaveSerializer.from_dict(raw), "舊版不再接受（只收 v6）")
