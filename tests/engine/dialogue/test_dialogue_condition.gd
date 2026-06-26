extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}
	var quests: Dictionary = {}   # id -> {"status","stage"}
	func is_quest_inactive(id) -> bool: return not quests.has(id)
	func is_quest_active(id) -> bool: return quests.has(id) and quests[id]["status"] == "active"
	func is_quest_done(id) -> bool: return quests.has(id) and quests[id]["status"] == "done"
	func quest_stage(id) -> int: return int(quests[id]["stage"]) if is_quest_active(id) else -1

func _ctx(gold := 0) -> FakeCtx:
	var c := FakeCtx.new()
	c.gold = gold
	return c

func test_null_require_passes():
	assert_true(DialogueCondition.passes(null, _ctx()))

func test_empty_require_passes():
	assert_true(DialogueCondition.passes({}, _ctx()))

func test_gold_gte_boundary():
	assert_true(DialogueCondition.passes({"gold_gte": 30}, _ctx(30)))
	assert_false(DialogueCondition.passes({"gold_gte": 30}, _ctx(29)))

func test_flag_is_true():
	var c := _ctx()
	c.flags["seen"] = true
	assert_true(DialogueCondition.passes({"flag": "seen", "is": true}, c))
	assert_false(DialogueCondition.passes({"flag": "seen", "is": false}, c))

func test_flag_is_false_when_unset():
	assert_true(DialogueCondition.passes({"flag": "seen", "is": false}, _ctx()))

func test_has_item():
	var c := _ctx()
	c.inventory.add("potion", 1)
	assert_true(DialogueCondition.passes({"has_item": "potion"}, c))
	assert_false(DialogueCondition.passes({"has_item": "elixir"}, c))

func test_multiple_keys_are_and():
	var c := _ctx(30)
	c.flags["seen"] = true
	assert_true(DialogueCondition.passes({"gold_gte": 30, "flag": "seen", "is": true}, c))
	assert_false(DialogueCondition.passes({"gold_gte": 31, "flag": "seen", "is": true}, c))

func test_unknown_key_fails():
	assert_false(DialogueCondition.passes({"weather": "rain"}, _ctx()))

func test_quest_inactive():
	var c := _ctx()
	assert_true(DialogueCondition.passes({"quest_inactive": "q"}, c))
	c.quests["q"] = {"status": "active", "stage": 0}
	assert_false(DialogueCondition.passes({"quest_inactive": "q"}, c))

func test_quest_active_and_done():
	var c := _ctx()
	c.quests["q"] = {"status": "active", "stage": 0}
	assert_true(DialogueCondition.passes({"quest_active": "q"}, c))
	assert_false(DialogueCondition.passes({"quest_done": "q"}, c))
	c.quests["q"] = {"status": "done", "stage": 4}
	assert_true(DialogueCondition.passes({"quest_done": "q"}, c))

func test_quest_stage_eq():
	var c := _ctx()
	c.quests["q"] = {"status": "active", "stage": 3}
	assert_true(DialogueCondition.passes({"quest_stage": {"id": "q", "eq": 3}}, c))
	assert_false(DialogueCondition.passes({"quest_stage": {"id": "q", "eq": 2}}, c))

func test_quest_stage_false_when_done():
	var c := _ctx()
	c.quests["q"] = {"status": "done", "stage": 4}
	assert_false(DialogueCondition.passes({"quest_stage": {"id": "q", "eq": 4}}, c))
