extends GutTest

# summary_lines 改吃 duck-typed q（kill 顯示由 q.kill_count 來）。FakeQ 模擬查詢介面。
class FakeQ:
	var kills: Dictionary = {}
	var items: Dictionary = {}
	func kill_count(id: String) -> int: return int(kills.get(id, 0))
	func item_count(id: String) -> int: return int(items.get(id, 0))
	func is_explored(_m: String, _c) -> bool: return false

var _def: QuestDef

func _resolve(id) -> QuestDef:
	return _def if id == "q" else null

func before_each():
	_def = QuestDef.parse({
		"id": "q", "title": "哥布林的威脅",
		"stages": [
			{"type": "kill", "monster": "goblin", "count": 3, "desc": "擊敗哥布林"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 10, "items": []},
	})

func test_summary_lists_active_with_progress():
	var quests := {"q": {"status": "active", "stage": 0}}
	var q := FakeQ.new(); q.kills["goblin"] = 1
	var lines := QuestLog.summary_lines(quests, Callable(self, "_resolve"), q)
	var joined := "\n".join(lines)
	assert_true(joined.contains("哥布林的威脅"))
	assert_true(joined.contains("擊敗哥布林 1/3"))

func test_summary_lists_done():
	var quests := {"q": {"status": "done", "stage": 2}}
	var lines := QuestLog.summary_lines(quests, Callable(self, "_resolve"), FakeQ.new())
	assert_true("\n".join(lines).contains("哥布林的威脅"))

func test_summary_empty_when_no_quests():
	var lines := QuestLog.summary_lines({}, Callable(self, "_resolve"), FakeQ.new())
	var joined := "\n".join(lines)
	assert_true(joined.contains("進行中"))
	assert_true(joined.contains("（無）"))
