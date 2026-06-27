extends GutTest

class FakeQ:
	var quests: Dictionary = {}
	var defeated: Dictionary = {}
	var items: Dictionary = {}
	func is_quest_active(id: String) -> bool:
		return quests.has(id) and String(quests[id].get("status", "")) == "active"
	func is_defeated(uid: String) -> bool: return defeated.has(uid)
	func item_count(id: String) -> int: return int(items.get(id, 0))

var _def: QuestDef
func _resolve(id) -> QuestDef: return _def if id == "q" else null

func before_each():
	_def = QuestDef.parse({
		"id": "q", "title": "哥布林的威脅",
		"stages": [
			{"type": "kill", "targets": ["u-a"], "desc": "擊敗哥布林"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 10, "items": []},
	})

func test_tracker_lines_shows_title_and_stage():
	var q := FakeQ.new(); q.quests["q"] = {"status": "active", "stage": 0}
	var lines := QuestTracker.tracker_lines("q", Callable(self, "_resolve"), q)
	var joined := "\n".join(lines)
	assert_true(joined.contains("哥布林的威脅"))
	assert_true(joined.contains("擊敗哥布林 0/1"))

func test_tracker_lines_empty_when_none():
	assert_eq(QuestTracker.tracker_lines("", Callable(self, "_resolve"), FakeQ.new()), [])

func test_tracker_lines_empty_when_not_active():
	var q := FakeQ.new(); q.quests["q"] = {"status": "done", "stage": 2}
	assert_eq(QuestTracker.tracker_lines("q", Callable(self, "_resolve"), q), [])
