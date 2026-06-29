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

func _state_with_inv(pairs: Dictionary) -> FakeState:
	var st := _state(1)
	for id in pairs:
		st.inventory.add(id, int(pairs[id]))
	st.party.members[0].hp = 5
	st.party.members[0].hp_max = 30
	return st

func _items_panel(st: FakeState) -> CharacterPanel:
	var panel := CharacterPanel.new()
	add_child_autofree(panel)
	panel.open(CharacterPanel.Tab.ITEMS, st)
	return panel

func test_enter_uses_consumable():
	var st := _state_with_inv({"potion": 2})
	var panel := _items_panel(st)
	# rows[0..2]=裝備槽；rows[3]=potion → 游標移到 3
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_ENTER))
	assert_eq(st.inventory.count_of("potion"), 1, "使用後背包減一")
	assert_gt(st.party.members[0].hp, 5, "HP 回復")
	assert_false(st.message_log.lines.is_empty(), "推了訊息")

func test_enter_equips_then_unequips():
	var st := _state_with_inv({"short_sword": 1})
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_DOWN))   # 落在 short_sword
	panel._unhandled_input(_key(KEY_ENTER))  # 裝備
	var m: Character = st.party.members[0]
	assert_true(m.equipment.is_equipped(Equipment.Slot.WEAPON), "已裝備")
	assert_eq(st.inventory.count_of("short_sword"), 0, "背包扣除")
	# 裝備後背包該列消失 → rows 只剩 3 個裝備槽，游標被夾到索引 2(飾品)。
	# 3 元素環按 2 次 UP：2→1→0，回到武器槽(rows[0])再卸下。
	panel._unhandled_input(_key(KEY_UP))
	panel._unhandled_input(_key(KEY_UP))
	panel._unhandled_input(_key(KEY_ENTER))  # 卸下
	assert_false(m.equipment.is_equipped(Equipment.Slot.WEAPON), "已卸下")
	assert_eq(st.inventory.count_of("short_sword"), 1, "回到背包")

func _caster_state(spells: Array, sp: int) -> FakeState:
	var st := _state(2)
	var caster: Character = st.party.members[0]
	caster.name = "梅"
	caster.char_class = "Cleric"
	caster.sp = sp
	caster.sp_max = 20
	caster.known_spells.assign(spells)
	# 第二位隊友受傷，當治療目標
	st.party.members[1].hp = 1
	st.party.members[1].hp_max = 30
	return st

func _spells_panel(st: FakeState) -> CharacterPanel:
	var panel := CharacterPanel.new()
	add_child_autofree(panel)
	panel.open(CharacterPanel.Tab.SPELLS, st)
	return panel

func test_enter_heal_picks_target_and_casts():
	var st := _caster_state(["heal"], 10)
	var panel := _spells_panel(st)
	panel._unhandled_input(_key(KEY_ENTER))   # heal → 進入選目標
	panel._unhandled_input(_key(KEY_DOWN))    # 目標游標移到隊友 1
	panel._unhandled_input(_key(KEY_ENTER))   # 確認施放
	assert_gt(st.party.members[1].hp, 1, "目標 HP 回復")
	assert_eq(st.party.members[0].sp, 8, "扣 SP 2")

func test_insufficient_sp_blocks_cast():
	var st := _caster_state(["heal"], 1)   # heal SP2 > 1
	var panel := _spells_panel(st)
	panel._unhandled_input(_key(KEY_ENTER))   # 進入選目標
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_ENTER))   # 嘗試施放
	assert_eq(st.party.members[1].hp, 1, "HP 不變")
	assert_eq(st.party.members[0].sp, 1, "SP 不變")

func test_combat_only_spell_does_nothing():
	var st := _caster_state(["spark"], 10)
	var panel := _spells_panel(st)
	panel._unhandled_input(_key(KEY_ENTER))   # spark 戰鬥限定 → 無效
	assert_eq(st.party.members[0].sp, 10, "SP 不變")

func test_recall_emits_world_spell_cast_and_closes():
	var st := _caster_state(["town_portal"], 10)
	var panel := _spells_panel(st)
	watch_signals(panel)
	panel._unhandled_input(_key(KEY_ENTER))   # town_portal(RECALL) → emit + 關閉
	assert_signal_emitted(panel, "world_spell_cast")
	assert_false(panel.is_open(), "施放後關閉")
	assert_eq(st.party.members[0].sp, 4, "扣 SP 6")
