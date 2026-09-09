extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}

func _data() -> DialogueData:
	return DialogueData.parse({
		"id": "d", "start": "root",
		"nodes": {
			"root": {
				"text": "hi",
				"choices": [
					{ "text": "buy", "require": {"gold_gte": 30},
					  "effects": [{"op": "gold", "value": -30}], "goto": "bought" },
					{ "text": "leave", "goto": null },
				],
			},
			"bought": { "text": "thanks", "choices": [ {"text": "ok", "goto": null} ] },
		},
	})

func _runner(gold := 0) -> DialogueRunner:
	var c := FakeCtx.new()
	c.gold = gold
	return DialogueRunner.new(_data(), c)

func test_starts_at_start_node():
	assert_eq(_runner().current_node()["text"], "hi")
	assert_false(_runner().is_finished())

func test_available_choices_filtered_by_require():
	assert_eq(_runner(0).available_choices().size(), 1)    # 只有 leave
	assert_eq(_runner(30).available_choices().size(), 2)   # buy + leave

func test_choose_applies_effects_and_advances():
	var r := _runner(50)
	var buy: Dictionary = r.available_choices()[0]
	var descs := r.choose(buy)
	assert_eq(r.current_node()["text"], "thanks")
	assert_false(r.is_finished())
	assert_eq(descs.events.size(), 1)

func test_choose_goto_null_finishes():
	var r := _runner(0)
	var leave: Dictionary = r.available_choices()[0]
	r.choose(leave)
	assert_true(r.is_finished())

func test_stale_choice_cannot_charge_or_advance():
	var ctx := FakeCtx.new()
	ctx.gold = 50
	var runner := DialogueRunner.new(_data(), ctx)
	var buy: Dictionary = runner.available_choices()[0]
	ctx.gold = 0
	var result := runner.choose(buy)
	assert_false(result.ok)
	assert_eq(ctx.gold, 0)
	assert_eq(runner.current_node()["text"], "hi")

func test_choice_cannot_be_replayed_after_leaving_node():
	var ctx := FakeCtx.new()
	ctx.gold = 100
	var runner := DialogueRunner.new(_data(), ctx)
	var buy: Dictionary = runner.available_choices()[0]
	assert_true(runner.choose(buy).ok)
	assert_false(runner.choose(buy).ok)
	assert_eq(ctx.gold, 70)
