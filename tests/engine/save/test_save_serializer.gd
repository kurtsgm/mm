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
