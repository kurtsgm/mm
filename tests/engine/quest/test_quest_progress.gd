extends GutTest

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

func _inv(id := "", n := 0) -> Inventory:
	var inv := Inventory.new()
	if id != "":
		inv.add(id, n)
	return inv

func test_kill_line_shows_count():
	var st := {"status": "active", "stage": 0, "count": 2}
	assert_eq(QuestProgress.stage_line(_def(), st, Callable(_inv(), "count_of")), "擊敗哥布林 2/3")

func test_collect_line_shows_have():
	var st := {"status": "active", "stage": 1, "count": 0}
	assert_eq(QuestProgress.stage_line(_def(), st, Callable(_inv("lucky_charm", 1), "count_of")), "取得信物 1/1")

func test_reach_line_is_desc_only():
	var st := {"status": "active", "stage": 2, "count": 0}
	assert_eq(QuestProgress.stage_line(_def(), st, Callable(_inv(), "count_of")), "前往瞭望點")

func test_done_line():
	var st := {"status": "done", "stage": 4, "count": 0}
	assert_eq(QuestProgress.stage_line(_def(), st, Callable(_inv(), "count_of")), "已完成")

func test_accepted_message():
	assert_eq(QuestProgress.accepted_message(_def()), "接下任務：哥布林的威脅")

func test_completed_message_lists_rewards():
	assert_eq(QuestProgress.completed_message(_def()), "任務完成：哥布林的威脅，獎勵：100 金幣、potion")
