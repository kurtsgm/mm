extends GutTest

# 狀態式 kill/collect 用 FakeQ；reach 改事件式（advance_reach 帶 map+pos，不走 q）。
class FakeQ:
	var kills: Dictionary = {}
	var items: Dictionary = {}
	func kill_count(id: String) -> int: return int(kills.get(id, 0))
	func item_count(id: String) -> int: return int(items.get(id, 0))

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

func test_initial_state():
	assert_eq(QuestSystem.initial_state(), {"status": "active", "stage": 0})

func test_catch_up_stops_at_reach():
	# reach 是事件式，catch_up 不自動過（即使其他條件都滿足）
	var q := FakeQ.new(); q.kills["goblin"] = 9; q.items["lucky_charm"] = 5
	var s := QuestSystem.catch_up(_def(), QuestSystem.initial_state(), q)
	assert_eq(s["stage"], 0)

func test_advance_reach_matching_then_chains():
	# 踏到 (wild_ne,3,3) → reach 過 → catch_up 把已滿足的 kill/collect 一併追認 → 停在 talk
	var q := FakeQ.new(); q.kills["goblin"] = 3; q.items["lucky_charm"] = 1
	var s := QuestSystem.advance_reach(_def(), QuestSystem.initial_state(), "wild_ne", Vector2i(3, 3), q)
	assert_eq(s["stage"], 3)
	assert_eq(s["status"], "active")

func test_advance_reach_wrong_cell_noop():
	var s := QuestSystem.advance_reach(_def(), QuestSystem.initial_state(), "wild_ne", Vector2i(0, 0), FakeQ.new())
	assert_eq(s["stage"], 0)

func test_advance_reach_wrong_map_noop():
	var s := QuestSystem.advance_reach(_def(), QuestSystem.initial_state(), "town_oak", Vector2i(3, 3), FakeQ.new())
	assert_eq(s["stage"], 0)

func test_advance_reach_on_non_reach_stage_noop():
	var s := QuestSystem.advance_reach(_def(), {"status": "active", "stage": 1}, "wild_ne", Vector2i(3, 3), FakeQ.new())
	assert_eq(s["stage"], 1)

func test_kill_state_based_absolute():
	var q := FakeQ.new(); q.kills["goblin"] = 3
	var s := QuestSystem.catch_up(_def(), {"status": "active", "stage": 1}, q)
	assert_eq(s["stage"], 2)   # kill 滿足 → 到 collect

func test_advance_talk_completes_last_stage():
	var s := QuestSystem.advance_talk(_def(), {"status": "active", "stage": 3}, FakeQ.new())
	assert_true(QuestSystem.is_complete(s))

func test_advance_talk_on_non_talk_is_noop():
	var s := QuestSystem.advance_talk(_def(), {"status": "active", "stage": 1}, FakeQ.new())
	assert_eq(s["stage"], 1)

func test_is_stage_satisfied_reach_and_talk_false():
	assert_false(QuestSystem.is_stage_satisfied(_def().stage(0), FakeQ.new()))  # reach
	assert_false(QuestSystem.is_stage_satisfied(_def().stage(3), FakeQ.new()))  # talk

func test_input_state_not_mutated():
	var before := {"status": "active", "stage": 1}
	var q := FakeQ.new(); q.kills["goblin"] = 3
	QuestSystem.catch_up(_def(), before, q)
	assert_eq(before["stage"], 1)

func test_done_state_unchanged():
	var s := QuestSystem.catch_up(_def(), {"status": "done", "stage": 4}, FakeQ.new())
	assert_eq(s["stage"], 4)
	assert_eq(s["status"], "done")
