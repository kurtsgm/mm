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

func test_arrows_switch_tabs_on_non_item_tabs():
	# 狀態/法術分頁的 ←→ 仍切頂層分頁（道具分頁則改切左右欄，見下方）。
	var panel := _panel(2)
	assert_eq(panel.current_tab(), CharacterPanel.Tab.STATUS)
	panel._unhandled_input(_key(KEY_LEFT))   # STATUS -左→ SPELLS(環狀)
	assert_eq(panel.current_tab(), CharacterPanel.Tab.SPELLS)
	panel._unhandled_input(_key(KEY_RIGHT))  # SPELLS -右→ STATUS
	assert_eq(panel.current_tab(), CharacterPanel.Tab.STATUS)

func test_tab_key_cycles_tabs():
	var panel := _panel(3)
	assert_eq(panel.current_tab(), CharacterPanel.Tab.STATUS)
	panel._unhandled_input(_key(KEY_TAB))
	assert_eq(panel.current_tab(), CharacterPanel.Tab.ITEMS, "Tab → 下一分頁")
	panel._unhandled_input(_key(KEY_TAB))
	assert_eq(panel.current_tab(), CharacterPanel.Tab.SPELLS)
	panel._unhandled_input(_key(KEY_TAB))         # 環狀回狀態
	assert_eq(panel.current_tab(), CharacterPanel.Tab.STATUS)
	panel._unhandled_input(_key(KEY_TAB, true))   # Shift+Tab 反向 → 法術
	assert_eq(panel.current_tab(), CharacterPanel.Tab.SPELLS)

func test_tab_key_does_not_change_member():
	var panel := _panel(3)
	assert_eq(panel.selected_index(), 0)
	panel._unhandled_input(_key(KEY_TAB))
	assert_eq(panel.selected_index(), 0, "Tab 只切分頁、不換角色")

func test_number_keys_select_member():
	var panel := _panel(3)
	assert_eq(panel.selected_index(), 0)
	panel._unhandled_input(_key(KEY_3))
	assert_eq(panel.selected_index(), 2, "數字鍵 3 → 第 3 位隊員")
	panel._unhandled_input(_key(KEY_1))
	assert_eq(panel.selected_index(), 0, "數字鍵 1 → 第 1 位隊員")
	panel._unhandled_input(_key(KEY_6))
	assert_eq(panel.selected_index(), 0, "超出隊伍人數的數字鍵忽略，維持原選")

func test_set_tab_updates_body_to_status_of_member():
	var panel := _panel(2)
	panel._unhandled_input(_key(KEY_2))  # 數字鍵選到 C1（Lv2）
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

func test_items_tab_shows_items_view():
	var st := _state_with_inv({"potion": 1})
	var panel := _items_panel(st)
	assert_not_null(_find_node(panel, "CharacterItemsView"), "道具分頁含 CharacterItemsView")

func test_items_arrows_switch_columns():
	var st := _state_with_inv({"potion": 2})
	var panel := _items_panel(st)
	assert_eq(panel.item_zone(), 0, "起始在裝備欄")
	panel._unhandled_input(_key(KEY_RIGHT))
	assert_eq(panel.item_zone(), 1, "→ 進背包欄")
	panel._unhandled_input(_key(KEY_LEFT))
	assert_eq(panel.item_zone(), 0, "← 回裝備欄")

func test_items_updown_moves_within_zone_only():
	# 背包欄內 ↑↓ 只在背包列間環狀，不會跳回裝備欄。
	var st := _state_with_inv({"potion": 2, "short_sword": 1})
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_RIGHT))   # 進背包欄
	panel._unhandled_input(_key(KEY_DOWN))
	assert_eq(panel.item_zone(), 1, "↓ 後仍在背包欄")

# ── 邊界外溢：分頁與左右欄排成同一條水平軸，←→ 連續貫穿 ──

func test_items_left_at_equip_spills_to_status():
	var st := _state_with_inv({"potion": 2})
	var panel := _items_panel(st)
	assert_eq(panel.item_zone(), 0, "在裝備欄")
	panel._unhandled_input(_key(KEY_LEFT))    # 裝備欄再往左 → 外溢回狀態
	assert_eq(panel.current_tab(), CharacterPanel.Tab.STATUS, "← 外溢到狀態分頁")

func test_items_right_at_bag_spills_to_spells():
	var st := _state_with_inv({"potion": 2})
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_RIGHT))   # 裝備 → 背包
	assert_eq(panel.item_zone(), 1)
	panel._unhandled_input(_key(KEY_RIGHT))   # 背包再往右 → 外溢到法術
	assert_eq(panel.current_tab(), CharacterPanel.Tab.SPELLS, "→ 外溢到法術分頁")

func test_items_right_with_empty_bag_spills_to_spells():
	var st := _state_with_inv({})             # 背包空 → 裝備是唯一欄
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_RIGHT))   # 無背包可去 → 直接外溢到法術
	assert_eq(panel.current_tab(), CharacterPanel.Tab.SPELLS, "空背包時 → 外溢到法術")

func test_enter_items_from_status_lands_on_equip():
	var panel := _panel(2)                     # 開在狀態
	panel._unhandled_input(_key(KEY_RIGHT))    # 狀態 → 道具（從左邊進）
	assert_eq(panel.current_tab(), CharacterPanel.Tab.ITEMS)
	assert_eq(panel.item_zone(), 0, "從左邊進道具頁 → 落在裝備欄")

func test_enter_items_from_spells_lands_on_bag():
	var st := _state_with_inv({"potion": 2})
	var panel := _items_panel(st)
	panel.set_tab(CharacterPanel.Tab.SPELLS)   # 移到法術
	panel._unhandled_input(_key(KEY_LEFT))     # 法術 → 道具（從右邊進）
	assert_eq(panel.current_tab(), CharacterPanel.Tab.ITEMS)
	assert_eq(panel.item_zone(), 1, "從右邊進道具頁 → 落在背包欄")

func test_tab_labels_show_hotkeys():
	var panel := _panel(2)
	assert_true(_find_label_containing(panel, "道具").text.contains("(I)"), "道具分頁標籤顯示 (I)")
	assert_true(_find_label_containing(panel, "狀態").text.contains("(C)"), "狀態分頁標籤顯示 (C)")
	assert_true(_find_label_containing(panel, "法術").text.contains("(M)"), "法術分頁標籤顯示 (M)")

func _find_label_containing(n: Node, sub: String) -> Label:
	if n is Label and (n as Label).text.contains(sub):
		return n
	for c in n.get_children():
		var r := _find_label_containing(c, sub)
		if r != null:
			return r
	return null

# ── 道具動作確認 modal ──

func test_enter_opens_confirm_without_acting():
	var st := _state_with_inv({"potion": 2})
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_RIGHT))   # 進背包欄，游標落在 potion
	panel._unhandled_input(_key(KEY_ENTER))   # 開啟確認 modal（不直接使用）
	assert_true(panel.confirm_open(), "Enter 開啟確認 modal")
	assert_eq(st.inventory.count_of("potion"), 2, "尚未使用")

func test_panel_has_hidden_confirm_dialog_initially():
	var panel := _items_panel(_state_with_inv({"potion": 1}))
	var d := _find_node(panel, "ItemConfirmDialog")
	assert_not_null(d, "面板含 ItemConfirmDialog")
	assert_false((d as Control).visible, "初始隱藏")

func test_confirm_use_consumes_and_heals():
	var st := _state_with_inv({"potion": 2})   # members[0].hp = 5/30（受傷）
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_RIGHT))
	panel._unhandled_input(_key(KEY_ENTER))   # 開 modal（游標預設在「使用」）
	panel._unhandled_input(_key(KEY_ENTER))   # 確認使用
	assert_false(panel.confirm_open(), "確認後關閉 modal")
	assert_eq(st.inventory.count_of("potion"), 1, "使用後背包減一")
	assert_gt(st.party.members[0].hp, 5, "HP 回復")

func test_esc_cancels_confirm_keeps_panel_open():
	var st := _state_with_inv({"potion": 2})
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_RIGHT))
	panel._unhandled_input(_key(KEY_ENTER))   # 開 modal
	panel._unhandled_input(_key(KEY_ESCAPE))  # 取消 modal
	assert_false(panel.confirm_open(), "Esc 關閉 modal")
	assert_true(panel.is_open(), "面板仍開")
	assert_eq(st.inventory.count_of("potion"), 2, "未使用")

func test_cancel_option_does_nothing():
	var st := _state_with_inv({"potion": 2})
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_RIGHT))
	panel._unhandled_input(_key(KEY_ENTER))   # 開 modal
	panel._unhandled_input(_key(KEY_RIGHT))   # 游標移到「取消」
	panel._unhandled_input(_key(KEY_ENTER))   # 選取消
	assert_false(panel.confirm_open())
	assert_eq(st.inventory.count_of("potion"), 2, "未使用")

func test_unusable_consumable_offers_dismiss_only():
	var st := _state_with_inv({"potion": 1})
	st.party.members[0].hp = st.party.members[0].hp_max   # 滿血 → 無法治療
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_RIGHT))
	panel._unhandled_input(_key(KEY_ENTER))   # 開 modal
	assert_true(panel.confirm_open())
	assert_eq(panel.confirm_options(), ["確定"], "滿血時只給『確定』、不給『使用』")
	panel._unhandled_input(_key(KEY_ENTER))   # 確定 → 關閉、不消耗
	assert_false(panel.confirm_open())
	assert_eq(st.inventory.count_of("potion"), 1, "未消耗")

func test_confirm_equips_then_unequips():
	var st := _state_with_inv({"short_sword": 1})
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_RIGHT))   # 背包 short_sword
	panel._unhandled_input(_key(KEY_ENTER))   # modal「裝備」
	panel._unhandled_input(_key(KEY_ENTER))   # 確認裝備
	var m: Character = st.party.members[0]
	assert_true(m.equipment.is_equipped(Equipment.Slot.WEAPON), "已裝備")
	assert_eq(st.inventory.count_of("short_sword"), 0, "背包扣除")
	assert_eq(panel.item_zone(), 0, "背包空後退回裝備欄")
	panel._unhandled_input(_key(KEY_ENTER))   # modal「卸下」
	panel._unhandled_input(_key(KEY_ENTER))   # 確認卸下
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

func test_builds_party_rail_and_status_view():
	var panel := _panel(3)
	var rail := _find_node(panel, "PartyRail")
	var sv := _find_node(panel, "CharacterStatusView")
	assert_not_null(rail, "面板含 PartyRail")
	assert_not_null(sv, "面板含 CharacterStatusView")
	assert_eq((rail as PartyRail).row_count(), 3)

func test_rail_selection_follows_member_switch():
	var panel := _panel(3)
	var rail := _find_node(panel, "PartyRail") as PartyRail
	assert_eq(rail.selected(), 0)
	panel._unhandled_input(_key(KEY_3))
	assert_eq(rail.selected(), 2, "1-6 切換時直欄同步高亮")

func _find_node(n: Node, cls: String) -> Node:
	if n.get_class() == cls or (n.get_script() != null and n.get_script().get_global_name() == cls):
		return n
	for c in n.get_children():
		var r := _find_node(c, cls)
		if r != null:
			return r
	return null
