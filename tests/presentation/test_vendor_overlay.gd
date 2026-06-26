extends GutTest

class FakeState:
	var gold: int = 0
	var inventory := Inventory.new()
	var party := FakeParty.new()

class FakeParty:
	var members: Array = []

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev

func _overlay() -> VendorOverlay:
	var ov := VendorOverlay.new()
	add_child_autofree(ov)
	return ov

func _goods() -> Dictionary:
	return {"id": "s", "kind": "goods", "name": "店", "sell_factor": 0.5,
			"stock": ["potion", "short_sword"]}

func test_goods_open_lists_stock():
	var st := FakeState.new()
	st.gold = 999
	var ov := _overlay()
	ov.open(_goods(), st)
	assert_true(ov.is_open())
	assert_string_contains(ov._panel.text, "店")
	assert_string_contains(ov._panel.text, "藥水")   # potion.display_name；若不同改為實際名

func test_goods_buy_deducts_gold_and_adds_item():
	var st := FakeState.new()
	st.gold = 999
	var ov := _overlay()
	ov.open(_goods(), st)
	watch_signals(ov)
	# cursor 預設指第一項(potion)；Enter 購買
	ov._unhandled_input(_key(KEY_ENTER))
	assert_lt(st.gold, 999)
	assert_eq(st.inventory.count_of("potion"), 1)
	assert_signal_emitted(ov, "transacted")

func test_goods_esc_closes_and_finishes():
	var st := FakeState.new()
	var ov := _overlay()
	ov.open(_goods(), st)
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_ESCAPE))
	assert_false(ov.is_open())
	assert_signal_emitted(ov, "finished")
