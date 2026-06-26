extends GutTest

# stage_line 改吃 duck-typed q（kill/collect 顯示由查詢得來、夾住目標）。
class FakeQ:
	var kills: Dictionary = {}
	var items: Dictionary = {}
	func kill_count(id: String) -> int: return int(kills.get(id, 0))
	func item_count(id: String) -> int: return int(items.get(id, 0))
	func is_explored(_m: String, _c) -> bool: return false

func _def() -> QuestDef:
	return QuestDef.parse({
		"id": "q", "title": "哥布林的威脅",
		"stages": [
			{"type": "kill", "monster": "goblin", "count": 3, "desc": "擊敗哥布林"},
			{"type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得信物"},
			{"type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "前往瞭望點"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 100, "items": ["potion"]},
	})

func test_kill_line_shows_count():
	var q := FakeQ.new(); q.kills["goblin"] = 2
	assert_eq(QuestProgress.stage_line(_def(), {"status": "active", "stage": 0}, q), "擊敗哥布林 2/3")

func test_kill_line_clamped_to_target():
	var q := FakeQ.new(); q.kills["goblin"] = 9
	assert_eq(QuestProgress.stage_line(_def(), {"status": "active", "stage": 0}, q), "擊敗哥布林 3/3")

func test_collect_line_shows_have():
	var q := FakeQ.new(); q.items["lucky_charm"] = 1
	assert_eq(QuestProgress.stage_line(_def(), {"status": "active", "stage": 1}, q), "取得信物 1/1")

func test_reach_line_is_desc_only():
	assert_eq(QuestProgress.stage_line(_def(), {"status": "active", "stage": 2}, FakeQ.new()), "前往瞭望點")

func test_done_line():
	assert_eq(QuestProgress.stage_line(_def(), {"status": "done", "stage": 4}, FakeQ.new()), "已完成")

func test_accepted_message():
	assert_eq(QuestProgress.accepted_message(_def()), "接下任務：哥布林的威脅")

func test_completed_message_lists_rewards():
	assert_eq(QuestProgress.completed_message(_def()), "任務完成：哥布林的威脅，獎勵：100 金幣、potion")
