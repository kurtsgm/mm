extends GutTest

func _sample() -> SaveData:
	var a := Character.new()
	a.name = "Gerard"; a.char_class = "Knight"; a.level = 3
	a.hp = 28; a.hp_max = 30; a.sp = 0; a.sp_max = 0
	a.might = 15; a.intellect = 12; a.personality = 11; a.endurance = 14
	a.speed = 13; a.accuracy = 13; a.luck = 11
	a.condition = Character.Condition.OK; a.experience = 250
	var b := Character.new()
	b.name = "Marcus"; b.char_class = "Cleric"; b.level = 3
	b.hp = 0; b.hp_max = 22; b.sp = 9; b.sp_max = 14
	b.might = 10; b.intellect = 16; b.personality = 17; b.endurance = 12
	b.speed = 11; b.accuracy = 10; b.luck = 9
	b.condition = Character.Condition.UNCONSCIOUS; b.experience = 240
	var p := Party.new()
	p.members = [a, b]
	var d := SaveData.new()
	d.gold = 120; d.map_id = "level01"
	d.player_pos = Vector2i(3, 5); d.player_facing = GridDirection.Dir.EAST
	d.party = p
	d.cleared_encounters = {"level01": [Vector2i(4, 2), Vector2i(7, 9)], "level02": [Vector2i(1, 1)]}
	return d

func test_roundtrip_preserves_scalars_and_party():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_sample()))
	assert_not_null(back)
	assert_eq(back.gold, 120)
	assert_eq(back.map_id, "level01")
	assert_eq(back.player_pos, Vector2i(3, 5))
	assert_eq(back.player_facing, GridDirection.Dir.EAST)
	assert_eq(back.party.members.size(), 2)
	var a2: Character = back.party.members[0]
	assert_eq(a2.name, "Gerard")
	assert_eq(a2.level, 3)
	assert_eq(a2.hp, 28)
	assert_eq(a2.hp_max, 30)
	assert_eq(a2.might, 15)
	assert_eq(a2.accuracy, 13)
	assert_eq(a2.experience, 250)
	var b2: Character = back.party.members[1]
	assert_eq(b2.name, "Marcus")
	assert_eq(b2.condition, Character.Condition.UNCONSCIOUS)
	assert_eq(b2.sp_max, 14)

func test_roundtrip_cleared_encounters_multi_map():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_sample()))
	assert_eq(back.cleared_encounters.size(), 2)
	var l1: Array = back.cleared_encounters["level01"]
	assert_eq(l1.size(), 2)
	assert_true(l1.has(Vector2i(4, 2)))
	assert_true(l1.has(Vector2i(7, 9)))
	assert_true(back.cleared_encounters["level02"].has(Vector2i(1, 1)))

func test_roundtrip_empty_party():
	var d := SaveData.new()
	d.party = Party.new()
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(d))
	assert_not_null(back)
	assert_eq(back.party.members.size(), 0)

func test_to_dict_has_version_and_meta():
	var raw := SaveSerializer.to_dict(_sample())
	assert_eq(raw["version"], SaveSerializer.VERSION)
	assert_eq(raw["meta"]["map_id"], "level01")
	assert_eq(raw["meta"]["gold"], 120)
	assert_eq(raw["meta"]["party"].size(), 2)
	assert_eq(raw["meta"]["party"][0]["name"], "Gerard")

func test_from_dict_rejects_version_mismatch():
	var raw := SaveSerializer.to_dict(_sample())
	raw["version"] = 999
	assert_null(SaveSerializer.from_dict(raw))

func test_from_dict_rejects_missing_state():
	assert_null(SaveSerializer.from_dict({"version": SaveSerializer.VERSION}))

func test_to_dict_version_is_9():
	assert_eq(SaveSerializer.to_dict(_sample())["version"], 9)

func test_roundtrip_explored_multi_map():
	var d := _sample()
	d.explored = {
		"level01": {Vector2i(1, 1): true, Vector2i(2, 1): true},
		"town_oak": {Vector2i(0, 0): true},
	}
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(d))
	assert_eq(back.explored.size(), 2)
	assert_true(back.explored["level01"].has(Vector2i(1, 1)))
	assert_true(back.explored["level01"].has(Vector2i(2, 1)))
	assert_true(back.explored["town_oak"].has(Vector2i(0, 0)))

func test_missing_explored_loads_empty():
	var raw := {
		"version": SaveSerializer.VERSION,
		"state": {
			"gold": 0, "map_id": "level01",
			"player_pos": [1, 1], "player_facing": 0,
			"party": [], "inventory": [], "cleared_encounters": {},
		},
	}
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back)
	assert_eq(back.explored.size(), 0)

func test_explored_malformed_coords_skipped():
	var raw := SaveSerializer.to_dict(_sample())
	raw["state"]["explored"] = {"level01": [[1, 1], [9]]}  # 第二個 size<2 → 畸形
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back)
	assert_true(back.explored["level01"].has(Vector2i(1, 1)))
	assert_eq(back.explored["level01"].size(), 1, "畸形座標被略過")

func test_opened_objects_round_trip():
	var d := SaveData.new()
	d.opened_objects = {"town_oak": [Vector2i(1, 1), Vector2i(3, 1)]}
	var raw := SaveSerializer.to_dict(d)
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.opened_objects, {"town_oak": [Vector2i(1, 1), Vector2i(3, 1)]})

func test_opened_objects_absent_is_empty():
	# 舊檔（無此欄）→ 空字典，不報錯（向後相容）
	var raw := {"version": SaveSerializer.VERSION, "state": {"player_pos": [0, 0]}}
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back)
	assert_eq(back.opened_objects, {})
