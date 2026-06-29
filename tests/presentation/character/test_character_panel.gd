extends GutTest

class FakeLog:
	var lines: Array = []
	func push(t) -> void:
		lines.append(String(t))

class FakeState:
	var party: Party
	var inventory: Inventory
	var message_log

func _state(n: int) -> FakeState:
	var st := FakeState.new()
	st.message_log = FakeLog.new()
	st.inventory = Inventory.new()
	var p := Party.new()
	var ms: Array[Character] = []
	for i in n:
		var c := Character.new()
		c.name = "C%d" % i
		c.char_class = "Knight"
		c.level = 1 + i
		c.hp = 10
		c.hp_max = 30
		ms.append(c)
	p.members = ms
	st.party = p
	return st

func _panel(n: int) -> CharacterPanel:
	var panel := CharacterPanel.new()
	add_child_autofree(panel)
	panel.open(CharacterPanel.Tab.STATUS, _state(n))
	return panel

func _key(code: int, shift := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.shift_pressed = shift
	return ev

func test_open_close_visibility_and_signal():
	var panel := _panel(3)
	assert_true(panel.is_open())
	watch_signals(panel)
	panel._unhandled_input(_key(KEY_ESCAPE))
	assert_false(panel.is_open())
	assert_signal_emitted(panel, "closed")

func test_open_lands_on_requested_tab():
	var panel := CharacterPanel.new()
	add_child_autofree(panel)
	panel.open(CharacterPanel.Tab.SPELLS, _state(2))
	assert_eq(panel.current_tab(), CharacterPanel.Tab.SPELLS)

func test_arrows_switch_tabs():
	var panel := _panel(2)
	assert_eq(panel.current_tab(), CharacterPanel.Tab.STATUS)
	panel._unhandled_input(_key(KEY_RIGHT))
	assert_eq(panel.current_tab(), CharacterPanel.Tab.ITEMS)
	panel._unhandled_input(_key(KEY_LEFT))
	assert_eq(panel.current_tab(), CharacterPanel.Tab.STATUS)

func test_tab_key_cycles_member():
	var panel := _panel(3)
	assert_eq(panel.selected_index(), 0)
	panel._unhandled_input(_key(KEY_TAB))
	assert_eq(panel.selected_index(), 1)
	panel._unhandled_input(_key(KEY_TAB, true))  # Shift+Tab
	assert_eq(panel.selected_index(), 0)
	panel._unhandled_input(_key(KEY_TAB, true))  # 環狀回到尾端
	assert_eq(panel.selected_index(), 2)

func test_set_tab_updates_body_to_status_of_member():
	var panel := _panel(2)
	panel._unhandled_input(_key(KEY_TAB))  # 選到 C1（Lv2）
	assert_true(panel.body_text().contains("C1"), "body 顯示目前隊員")
	assert_true(panel.body_text().contains("Lv2"))
