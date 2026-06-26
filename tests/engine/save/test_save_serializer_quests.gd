extends GutTest

func _data() -> SaveData:
	var d := SaveData.new()
	d.party = Party.new()
	d.inventory = Inventory.new()
	d.quests = {"q": {"status": "active", "stage": 1}}
	d.kill_counts = {"goblin": 5, "ogre": 1}
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

func test_kill_counts_round_trip():
	var raw := SaveSerializer.to_dict(_data())
	var back := SaveSerializer.from_dict(raw)
	assert_eq(int(back.kill_counts["goblin"]), 5)
	assert_eq(int(back.kill_counts["ogre"]), 1)

func test_kill_counts_absent_is_empty():
	var raw := SaveSerializer.to_dict(_data())
	raw["state"].erase("kill_counts")
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.kill_counts, {})

func test_version_is_7():
	assert_eq(SaveSerializer.to_dict(_data())["version"], 7)

func test_old_version_rejected():
	var raw := SaveSerializer.to_dict(_data())
	raw["version"] = 6
	assert_null(SaveSerializer.from_dict(raw), "舊版不再接受（只收 v7）")
