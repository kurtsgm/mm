extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}

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
