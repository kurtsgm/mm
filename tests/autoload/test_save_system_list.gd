extends GutTest

const SaveSystemScript := preload("res://autoload/save_system.gd")

var _sys

func before_each():
	_sys = SaveSystemScript.new()
	add_child_autofree(_sys)

func after_each():
	for slot in SaveSystemScript.SLOT_COUNT:
		_sys.delete_slot(slot)

func _sample() -> SaveData:
	var c := Character.new()
	c.name = "Hero"; c.level = 4
	var p := Party.new()
	p.members = [c]
	var d := SaveData.new()
	d.gold = 88; d.map_id = "level01"
	d.party = p
	return d

func test_list_slots_reports_occupied_and_empty():
	_sys.write_slot(0, _sample())
	_sys.write_slot(2, _sample())
	var slots: Array = _sys.list_slots()
	assert_eq(slots.size(), SaveSystemScript.SLOT_COUNT)
	assert_false(slots[0].is_empty(), "第 0 槽應有 meta")
	assert_eq(slots[0]["map_id"], "level01")
	assert_eq(int(slots[0]["gold"]), 88)
	assert_true(slots[0].has("saved_at"), "meta 應含 saved_at 時間戳")
	assert_true(slots[1].is_empty(), "第 1 槽應為空")
	assert_false(slots[2].is_empty(), "第 2 槽應有 meta")
