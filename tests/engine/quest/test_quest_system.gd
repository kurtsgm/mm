extends GutTest

func _def() -> QuestDef:
	return QuestDef.parse({
		"id": "q", "title": "T",
		"stages": [
			{"type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "前往"},
			{"type": "kill", "monster": "goblin", "count": 3, "desc": "擊敗"},
			{"type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 10, "items": []},
	})

func _inv(id := "", n := 0) -> Inventory:
	var inv := Inventory.new()
	if id != "":
		inv.add(id, n)
	return inv

func test_initial_state():
	var s := QuestSystem.initial_state()
	assert_eq(s, {"status": "active", "stage": 0, "count": 0})

func test_reach_advances_on_match():
	var s := QuestSystem.notify_enter(_def(), QuestSystem.initial_state(), "wild_ne", Vector2i(3, 3))
	assert_eq(s["stage"], 1)
	assert_eq(s["count"], 0)

func test_reach_no_advance_on_wrong_cell():
	var s := QuestSystem.notify_enter(_def(), QuestSystem.initial_state(), "wild_ne", Vector2i(0, 0))
	assert_eq(s["stage"], 0)

func test_kill_counts_then_advances():
	var st := {"status": "active", "stage": 1, "count": 0}
	st = QuestSystem.notify_kill(_def(), st, "goblin")
	assert_eq(st["count"], 1)
	st = QuestSystem.notify_kill(_def(), st, "goblin")
	st = QuestSystem.notify_kill(_def(), st, "goblin")
	assert_eq(st["stage"], 2)
	assert_eq(st["count"], 0)

func test_kill_wrong_monster_ignored():
	var st := {"status": "active", "stage": 1, "count": 0}
	st = QuestSystem.notify_kill(_def(), st, "ogre")
	assert_eq(st["count"], 0)

func test_kill_on_non_kill_stage_ignored():
	var st := QuestSystem.notify_kill(_def(), QuestSystem.initial_state(), "goblin")
	assert_eq(st["stage"], 0)
	assert_eq(st["count"], 0)

func test_collect_advances_when_have_enough():
	var st := {"status": "active", "stage": 2, "count": 0}
	st = QuestSystem.check_collect(_def(), st, Callable(_inv("lucky_charm", 1), "count_of"))
	assert_eq(st["stage"], 3)

func test_collect_no_advance_when_short():
	var st := {"status": "active", "stage": 2, "count": 0}
	st = QuestSystem.check_collect(_def(), st, Callable(_inv(), "count_of"))
	assert_eq(st["stage"], 2)

func test_talk_advances_and_completes_last_stage():
	var st := {"status": "active", "stage": 3, "count": 0}
	st = QuestSystem.notify_advance(_def(), st)
	assert_true(QuestSystem.is_complete(st))

func test_input_state_not_mutated():
	var before := QuestSystem.initial_state()
	QuestSystem.notify_enter(_def(), before, "wild_ne", Vector2i(3, 3))
	assert_eq(before["stage"], 0)  # 原 state 未被改動

func test_done_state_ignores_events():
	var st := {"status": "done", "stage": 4, "count": 0}
	st = QuestSystem.notify_advance(_def(), st)
	assert_eq(st["stage"], 4)
