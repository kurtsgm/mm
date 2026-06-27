extends GutTest

func _data() -> SaveData:
	var d := SaveData.new()
	d.party = Party.new()
	d.inventory = Inventory.new()
	d.flags = {"heard_rumor": true}
	d.triggered_scenes = {"town_oak": [Vector2i(1, 3)]}
	return d

func test_version_is_9():
	assert_eq(SaveSerializer.to_dict(_data())["version"], 9)

func test_roundtrip_flags_and_scenes():
	var raw := SaveSerializer.to_dict(_data())
	var back := SaveSerializer.from_dict(raw)
	assert_true(back.flags.has("heard_rumor"))
	assert_eq(back.triggered_scenes["town_oak"][0], Vector2i(1, 3))

func test_missing_flags_and_scenes_load_empty():
	var raw := SaveSerializer.to_dict(_data())
	raw["state"].erase("flags")
	raw["state"].erase("triggered_scenes")
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back)
	assert_eq(back.flags, {})
	assert_eq(back.triggered_scenes, {})
