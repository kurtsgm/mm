extends GutTest

func test_defaults():
	var d := SaveData.new()
	assert_eq(d.gold, 0)
	assert_eq(d.map_id, "")
	assert_eq(d.player_pos, Vector2i.ZERO)
	assert_eq(d.player_facing, 0)
	assert_null(d.party)
	assert_eq(d.cleared_encounters.size(), 0)

func test_holds_fields():
	var d := SaveData.new()
	d.gold = 120
	d.map_id = "level01"
	d.player_pos = Vector2i(3, 5)
	d.player_facing = 1
	d.party = Party.new()
	d.cleared_encounters = {"level01": [Vector2i(4, 2)]}
	assert_eq(d.gold, 120)
	assert_eq(d.map_id, "level01")
	assert_eq(d.player_pos, Vector2i(3, 5))
	assert_eq(d.player_facing, 1)
	assert_not_null(d.party)
	assert_eq(d.cleared_encounters["level01"].size(), 1)
