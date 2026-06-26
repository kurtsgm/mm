extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}

func test_triggers_when_no_require_and_not_once():
	assert_true(SceneTrigger.should_trigger({"dialogue": "d"}, FakeCtx.new(), false))

func test_once_already_triggered_blocks():
	assert_false(SceneTrigger.should_trigger({"dialogue": "d", "once": true}, FakeCtx.new(), true))

func test_non_once_retriggers_even_if_seen():
	assert_true(SceneTrigger.should_trigger({"dialogue": "d", "once": false}, FakeCtx.new(), true))

func test_require_must_pass():
	var c := FakeCtx.new()
	assert_false(SceneTrigger.should_trigger({"dialogue": "d", "require": {"gold_gte": 10}}, c, false))
	c.gold = 10
	assert_true(SceneTrigger.should_trigger({"dialogue": "d", "require": {"gold_gte": 10}}, c, false))
