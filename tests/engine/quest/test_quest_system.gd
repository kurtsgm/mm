extends GutTest

# 狀態式 QuestSystem：目標由對持久狀態查詢決定。FakeQ 模擬 GameState 的查詢介面。
class FakeQ:
	var kills: Dictionary = {}      # monster_id -> int
	var items: Dictionary = {}      # item_id -> int
	var explored: Dictionary = {}   # map_id -> Dictionary[cell->true]
	func kill_count(id: String) -> int: return int(kills.get(id, 0))
	func item_count(id: String) -> int: return int(items.get(id, 0))
	func is_explored(map_id: String, cell) -> bool:
		return explored.has(map_id) and explored[map_id].has(cell)

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

func test_catch_up_no_progress_stays():
	var s := QuestSystem.catch_up(_def(), QuestSystem.initial_state(), FakeQ.new())
	assert_eq(s["stage"], 0)

func test_catch_up_reach_then_stops_at_kill():
	var q := FakeQ.new()
	q.explored["wild_ne"] = {Vector2i(3, 3): true}
	var s := QuestSystem.catch_up(_def(), QuestSystem.initial_state(), q)
	assert_eq(s["stage"], 1)   # reach 追認過、kill 未足停下

func test_catch_up_chains_to_talk_then_stops():
	var q := FakeQ.new()
	q.explored["wild_ne"] = {Vector2i(3, 3): true}
	q.kills["goblin"] = 3
	q.items["lucky_charm"] = 1
	var s := QuestSystem.catch_up(_def(), QuestSystem.initial_state(), q)
	assert_eq(s["stage"], 3)            # reach→kill→collect 全追認、停在 talk
	assert_eq(s["status"], "active")

func test_catch_up_does_not_auto_pass_talk():
	var q := FakeQ.new()
	q.explored["wild_ne"] = {Vector2i(3, 3): true}
	q.kills["goblin"] = 9
	q.items["lucky_charm"] = 5
	var s := QuestSystem.catch_up(_def(), {"status": "active", "stage": 3}, q)
	assert_eq(s["stage"], 3)

func test_kill_absolute_retroactive():
	# kill 用絕對總計：stage 1 在 q.kills>=3 即滿足（與何時殺無關）
	var q := FakeQ.new(); q.kills["goblin"] = 3
	var s := QuestSystem.catch_up(_def(), {"status": "active", "stage": 1}, q)
	assert_eq(s["stage"], 2)

func test_advance_talk_completes_last_stage():
	var s := QuestSystem.advance_talk(_def(), {"status": "active", "stage": 3}, FakeQ.new())
	assert_true(QuestSystem.is_complete(s))

func test_advance_talk_on_non_talk_is_noop():
	var s := QuestSystem.advance_talk(_def(), {"status": "active", "stage": 1}, FakeQ.new())
	assert_eq(s["stage"], 1)

func test_is_stage_satisfied_talk_false():
	assert_false(QuestSystem.is_stage_satisfied(_def().stage(3), FakeQ.new()))

func test_input_state_not_mutated():
	var before := {"status": "active", "stage": 1}
	var q := FakeQ.new(); q.kills["goblin"] = 3
	QuestSystem.catch_up(_def(), before, q)
	assert_eq(before["stage"], 1)

func test_done_state_unchanged():
	var s := QuestSystem.catch_up(_def(), {"status": "done", "stage": 4}, FakeQ.new())
	assert_eq(s["stage"], 4)
	assert_eq(s["status"], "done")
