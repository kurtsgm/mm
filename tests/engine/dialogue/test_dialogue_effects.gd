extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}
	var accepted: Array = []
	var advanced: Array = []
	func accept_quest(id) -> void: accepted.append(id)
	func advance_quest(id) -> void: advanced.append(id)

func test_null_returns_empty():
	assert_eq(DialogueEffects.apply(null, FakeCtx.new()), [])

func test_gold_add_and_subtract():
	var c := FakeCtx.new()
	c.gold = 50
	DialogueEffects.apply([{"op": "gold", "value": -20}], c)
	assert_eq(c.gold, 30)
	DialogueEffects.apply([{"op": "gold", "value": 5}], c)
	assert_eq(c.gold, 35)

func test_gold_clamped_at_zero():
	var c := FakeCtx.new()
	c.gold = 10
	DialogueEffects.apply([{"op": "gold", "value": -999}], c)
	assert_eq(c.gold, 0)

func test_give_and_take_item():
	var c := FakeCtx.new()
	DialogueEffects.apply([{"op": "give", "item": "potion"}], c)
	assert_eq(c.inventory.count_of("potion"), 1)
	DialogueEffects.apply([{"op": "take", "item": "potion"}], c)
	assert_eq(c.inventory.count_of("potion"), 0)

func test_set_and_clear_flag():
	var c := FakeCtx.new()
	DialogueEffects.apply([{"op": "set_flag", "flag": "seen"}], c)
	assert_true(c.flags.has("seen"))
	DialogueEffects.apply([{"op": "clear_flag", "flag": "seen"}], c)
	assert_false(c.flags.has("seen"))

func test_applied_in_order_and_returns_descriptions():
	var c := FakeCtx.new()
	c.gold = 100
	var out := DialogueEffects.apply([
		{"op": "gold", "value": -30},
		{"op": "give", "item": "short_sword"},
	], c)
	assert_eq(c.gold, 70)
	assert_eq(c.inventory.count_of("short_sword"), 1)
	assert_eq(out.size(), 2)

func test_unknown_op_skipped():
	var c := FakeCtx.new()
	var out := DialogueEffects.apply([{"op": "teleport"}], c)
	assert_eq(out, [])

func test_accept_quest_op_calls_ctx():
	var c := FakeCtx.new()
	DialogueEffects.apply([{"op": "accept_quest", "quest": "q1"}], c)
	assert_eq(c.accepted, ["q1"])

func test_advance_quest_op_calls_ctx():
	var c := FakeCtx.new()
	DialogueEffects.apply([{"op": "advance_quest", "quest": "q1"}], c)
	assert_eq(c.advanced, ["q1"])

func test_quest_ops_emit_no_description():
	var c := FakeCtx.new()
	var out := DialogueEffects.apply([{"op": "accept_quest", "quest": "q1"}], c)
	assert_eq(out, [])  # toast 由 GameState 負責，避免重複
