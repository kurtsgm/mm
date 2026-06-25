extends GutTest

func _sample() -> SaveData:
	var c := Character.new()
	c.name = "Cassia"; c.known_spells = ["spark", "flame_wave"]
	var p := Party.new(); p.members = [c]
	var d := SaveData.new(); d.party = p; d.inventory = Inventory.new()
	return d

func test_known_spells_roundtrip():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_sample()))
	assert_not_null(back)
	assert_eq(back.party.members[0].known_spells, ["spark", "flame_wave"])

func test_version_is_3():
	assert_eq(SaveSerializer.to_dict(_sample())["version"], 3)

func test_version_2_save_gets_empty_known_spells():
	var raw := {
		"version": 2,
		"state": {
			"gold": 0, "map_id": "level01",
			"player_pos": [0, 0], "player_facing": 0,
			"party": [{"name": "Old", "level": 1, "hp": 5, "hp_max": 5}],
			"inventory": [], "cleared_encounters": {},
		},
	}
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back, "v2 舊檔仍可讀")
	assert_eq(back.party.members[0].known_spells, [])

func test_version_1_save_still_accepted():
	var raw := {
		"version": 1,
		"state": {
			"gold": 0, "map_id": "level01",
			"player_pos": [1, 1], "player_facing": 0,
			"party": [{"name": "Old", "level": 1, "hp": 5, "hp_max": 5}],
			"cleared_encounters": {},
		},
	}
	assert_not_null(SaveSerializer.from_dict(raw))
