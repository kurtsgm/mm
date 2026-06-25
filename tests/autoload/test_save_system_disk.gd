extends GutTest

const SaveSystemScript := preload("res://autoload/save_system.gd")
const TEST_SLOT := 3

var _sys

func before_each():
	_sys = SaveSystemScript.new()
	add_child_autofree(_sys)

func after_each():
	_sys.delete_slot(TEST_SLOT)

func _sample() -> SaveData:
	var c := Character.new()
	c.name = "Hero"; c.level = 4; c.hp = 20; c.hp_max = 25; c.experience = 500
	c.condition = Character.Condition.OK
	var p := Party.new()
	p.members = [c]
	var d := SaveData.new()
	d.gold = 77; d.map_id = "level01"
	d.player_pos = Vector2i(2, 6); d.player_facing = 2
	d.party = p
	d.cleared_encounters = {"level01": [Vector2i(5, 5)]}
	return d

func test_write_then_read_roundtrips_through_disk():
	assert_true(_sys.write_slot(TEST_SLOT, _sample()))
	assert_true(_sys.has_slot(TEST_SLOT))
	var back: SaveData = _sys.read_slot(TEST_SLOT)
	assert_not_null(back)
	assert_eq(back.gold, 77)
	assert_eq(back.map_id, "level01")
	assert_eq(back.player_pos, Vector2i(2, 6))
	assert_eq(back.player_facing, 2)
	assert_eq(back.party.members.size(), 1)
	assert_eq(back.party.members[0].name, "Hero")
	assert_eq(back.party.members[0].experience, 500)
	assert_true(back.cleared_encounters["level01"].has(Vector2i(5, 5)))

func test_read_missing_slot_returns_null():
	_sys.delete_slot(TEST_SLOT)
	assert_false(_sys.has_slot(TEST_SLOT))
	assert_null(_sys.read_slot(TEST_SLOT))

func test_read_corrupt_slot_returns_null():
	DirAccess.make_dir_recursive_absolute(SaveSystemScript.SAVE_DIR)
	var f := FileAccess.open(_sys._slot_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string("{ this is not valid json ")
	f.close()
	assert_null(_sys.read_slot(TEST_SLOT))
	# JSON.parse_string emits an engine error on malformed input; that error is
	# expected here, so mark it handled to keep GUT's error tracker from failing.
	for e in get_errors():
		e.handled = true

func test_delete_slot_removes_file():
	_sys.write_slot(TEST_SLOT, _sample())
	assert_true(_sys.has_slot(TEST_SLOT))
	_sys.delete_slot(TEST_SLOT)
	assert_false(_sys.has_slot(TEST_SLOT))
