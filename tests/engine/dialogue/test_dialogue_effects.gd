extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}
	var accepted: Array = []
	var advanced: Array = []
	func accept_quest(id) -> void: accepted.append(id)
	func advance_quest(id) -> void: advanced.append(id)
	func _quest_def(_id): return QuestDef.parse({"id": "q1", "stages": [{"type": "talk"}]})

func test_null_returns_empty():
	assert_eq(StoryEffects.apply(null, FakeCtx.new()).events, [])

func test_gold_add_and_subtract():
	var c := FakeCtx.new()
	c.gold = 50
	StoryEffects.apply([{"op": "gold", "value": -20}], c)
	assert_eq(c.gold, 30)
	StoryEffects.apply([{"op": "gold", "value": 5}], c)
	assert_eq(c.gold, 35)

func test_insufficient_gold_rejects_without_changes():
	var c := FakeCtx.new()
	c.gold = 10
	StoryEffects.apply([{"op": "gold", "value": -999}], c)
	assert_eq(c.gold, 10)

func test_give_and_take_item():
	var c := FakeCtx.new()
	StoryEffects.apply([{"op": "give", "item": "potion"}], c)
	assert_eq(c.inventory.count_of("potion"), 1)
	StoryEffects.apply([{"op": "take", "item": "potion"}], c)
	assert_eq(c.inventory.count_of("potion"), 0)

func test_set_and_clear_flag():
	var c := FakeCtx.new()
	StoryEffects.apply([{"op": "set_flag", "flag": "seen"}], c)
	assert_true(c.flags.has("seen"))
	StoryEffects.apply([{"op": "clear_flag", "flag": "seen"}], c)
	assert_false(c.flags.has("seen"))

func test_applied_in_order_and_returns_descriptions():
	var c := FakeCtx.new()
	c.gold = 100
	var out := StoryEffects.apply([
		{"op": "gold", "value": -30},
		{"op": "give", "item": "short_sword"},
	], c)
	assert_eq(c.gold, 70)
	assert_eq(c.inventory.count_of("short_sword"), 1)
	assert_eq(out.events.size(), 2)

func test_unknown_op_rejected():
	var c := FakeCtx.new()
	var out := StoryEffects.apply([{"op": "teleport"}], c)
	assert_eq(out.events, [])

func test_accept_quest_op_calls_ctx():
	var c := FakeCtx.new()
	StoryEffects.apply([{"op": "accept_quest", "quest": "q1"}], c)
	assert_eq(c.accepted, ["q1"])

func test_advance_quest_op_calls_ctx():
	var c := FakeCtx.new()
	StoryEffects.apply([{"op": "advance_quest", "quest": "q1"}], c)
	assert_eq(c.advanced, ["q1"])

func test_quest_ops_emit_no_description():
	var c := FakeCtx.new()
	var out := StoryEffects.apply([{"op": "accept_quest", "quest": "q1"}], c)
	assert_eq(out.events, [])  # toast 由 GameState 負責，避免重複

func test_failed_batch_never_leaves_partial_gold_flags_or_items():
	var ctx := FakeCtx.new()
	ctx.gold = 30
	var result := StoryEffects.apply([
		{"op": "gold", "value": -20},
		{"op": "set_flag", "flag": "paid"},
		{"op": "give", "item": "potion"},
		{"op": "take", "item": "antidote"},
	], ctx)
	assert_false(result.ok)
	assert_eq(ctx.gold, 30)
	assert_false(ctx.flags.has("paid"))
	assert_eq(ctx.inventory.count_of("potion"), 0)

func test_repeated_costs_checked_against_projected_balance():
	var ctx := FakeCtx.new()
	ctx.gold = 30
	assert_false(StoryEffects.apply([{"op": "gold", "value": -20}, {"op": "gold", "value": -20}], ctx).ok)
	assert_eq(ctx.gold, 30)
