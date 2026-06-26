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
	var price := int(ItemCatalog.get_item("potion").value)
	# cursor 預設指第一項(potion)；Enter 購買
	ov._unhandled_input(_key(KEY_ENTER))
	assert_eq(st.gold, 999 - price)   # 精確扣 potion.value，不只是 < 999
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

# --- 5b: spells + services ---
func _member(cls: String, cond := Character.Condition.OK) -> Character:
	var c := Character.new()
	c.name = cls
	c.char_class = cls
	c.hp = 5
	c.hp_max = 20
	c.sp = 0
	c.sp_max = 10
	c.condition = cond
	return c

func _state_with(members: Array, gold := 999) -> FakeState:
	var st := FakeState.new()
	st.gold = gold
	st.party.members = members
	return st

func _spells_vendor() -> Dictionary:
	return {"id": "m", "kind": "spells", "name": "塔", "spells": ["spark", "heal"]}

func test_spells_learn_flow():
	var sorc := _member("Sorcerer")
	var st := _state_with([sorc, _member("Knight")])
	var ov := _overlay()
	ov.open(_spells_vendor(), st)
	watch_signals(ov)
	# 選第一個法術 spark(arcane) → 進選角色 → 選 Sorcerer(合格) → Enter 學會
	ov._unhandled_input(_key(KEY_ENTER))        # 選 spark → 進選角色
	ov._unhandled_input(_key(KEY_ENTER))        # 選第一個合格對象
	assert_true(sorc.known_spells.has("spark"))
	assert_signal_emitted(ov, "transacted")

func _services_vendor() -> Dictionary:
	return {"id": "t", "kind": "services", "name": "神殿",
			"offers": [
				{"name": "復活", "cost": 100, "effect": "revive", "target": "character"},
				{"name": "住宿", "cost": 20, "effect": "rest", "target": "party"}]}

func test_service_rest_party_applies_all():
	var a := _member("Knight", Character.Condition.UNCONSCIOUS)
	a.hp = 0
	var b := _member("Cleric")
	var st := _state_with([a, b])
	var ov := _overlay()
	ov.open(_services_vendor(), st)
	watch_signals(ov)
	# 游標移到第二項(住宿/party) → Enter 直接套全隊
	ov._unhandled_input(_key(KEY_DOWN))
	ov._unhandled_input(_key(KEY_ENTER))
	assert_eq(a.hp, 20)
	assert_eq(a.condition, Character.Condition.OK)
	assert_signal_emitted(ov, "transacted")

func test_service_revive_picks_valid_target():
	var dead := _member("Knight", Character.Condition.DEAD)
	var st := _state_with([_member("Cleric"), dead])
	var ov := _overlay()
	ov.open(_services_vendor(), st)
	# 第一項(復活/character) → Enter 進選角色 → 只列死/昏迷者 → Enter 復活
	ov._unhandled_input(_key(KEY_ENTER))
	ov._unhandled_input(_key(KEY_ENTER))
	assert_eq(dead.condition, Character.Condition.OK)

# 控制器要求：heal_full 服務端對端覆蓋（治療傷勢，target=character）。
func _temple_heal_vendor() -> Dictionary:
	return {"id": "t2", "kind": "services", "name": "神殿",
			"offers": [
				{"name": "治療傷勢", "cost": 30, "effect": "heal_full", "target": "character"}]}

func test_service_heal_full_restores_hp():
	var hurt := _member("Knight")   # hp=5, hp_max=20, condition=OK（受傷但活著）
	var st := _state_with([hurt, _member("Cleric")])
	var ov := _overlay()
	ov.open(_temple_heal_vendor(), st)
	watch_signals(ov)
	# 第一項(治療傷勢/character) → Enter 進選角色 → 第一個可治療對象 → Enter 治療
	ov._unhandled_input(_key(KEY_ENTER))
	ov._unhandled_input(_key(KEY_ENTER))
	assert_eq(hurt.hp, hurt.hp_max)
	assert_signal_emitted(ov, "transacted")

# Minor #2：賣出後游標夾住（清單變短至空）。
func test_goods_sell_clamps_cursor_when_list_shortens():
	var st := FakeState.new()
	st.gold = 0
	st.inventory.add("potion", 1)   # 背包剛好 1 件可賣
	var ov := _overlay()
	ov.open(_goods(), st)
	watch_signals(ov)
	var before := st.gold
	var sell_price := int(floor(ItemCatalog.get_item("potion").value * 0.5))
	ov._unhandled_input(_key(KEY_TAB))     # 進賣模式
	ov._unhandled_input(_key(KEY_ENTER))   # 賣掉唯一一件
	assert_eq(st.gold, before + sell_price)         # +floor(value*sell_factor)
	assert_eq(st.inventory.count_of("potion"), 0)
	assert_signal_emitted(ov, "transacted")
	assert_eq(ov._goods_rows().size(), 0)            # 賣清單已空
	assert_true(ov._cursor >= 0)                     # 游標夾住、未越界
	assert_lt(ov._cursor, maxi(ov._goods_rows().size(), 1))

# Minor #3：金幣不足時標示且 Enter 不成交。
func test_goods_buy_insufficient_gold_marks_and_blocks():
	var price := int(ItemCatalog.get_item("potion").value)
	var st := FakeState.new()
	st.gold = price - 1   # 不足以買第一項(potion)
	var ov := _overlay()
	ov.open(_goods(), st)
	watch_signals(ov)
	assert_string_contains(ov._panel.text, "金幣不足")
	ov._unhandled_input(_key(KEY_ENTER))   # 嘗試購買→應被擋
	assert_eq(st.gold, price - 1)           # 金幣不變
	assert_eq(st.inventory.count_of("potion"), 0)   # 未取得物品
	assert_signal_not_emitted(ov, "transacted")

# Minor #4：法術金幣不足的無聲失敗路徑 → 不學會、不扣金、不發訊號，且面板顯示「金幣不足」回饋。
func test_spells_insufficient_gold_blocks_and_shows_feedback():
	var sorc := _member("Sorcerer")
	var cost := int(SpellBook.get_spell("spark").gold_cost)
	var st := _state_with([sorc, _member("Knight")], cost - 1)   # 不足以學 spark
	var ov := _overlay()
	ov.open(_spells_vendor(), st)
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_ENTER))        # 選 spark → 進選角色
	ov._unhandled_input(_key(KEY_ENTER))        # 選第一個合格對象(Sorcerer) → 嘗試學會
	assert_false(sorc.known_spells.has("spark"))     # 未學會
	assert_eq(st.gold, cost - 1)                     # 金幣不變
	assert_signal_not_emitted(ov, "transacted")
	assert_string_contains(ov._panel.text, "金幣不足")   # 面板回饋

# Minor #4：服務金幣不足的無聲失敗路徑 → 不套效果、不扣金、不發訊號，且面板顯示「金幣不足」回饋。
func test_service_insufficient_gold_blocks_and_shows_feedback():
	var dead := _member("Knight", Character.Condition.DEAD)
	var st := _state_with([_member("Cleric"), dead], 0)   # 復活需 100 金，身上 0
	var ov := _overlay()
	ov.open(_services_vendor(), st)
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_ENTER))        # 第一項(復活/character) → 進選角色
	ov._unhandled_input(_key(KEY_ENTER))        # 選第一個合格對象(死者) → 嘗試復活
	assert_eq(dead.condition, Character.Condition.DEAD)   # 仍死亡（未復活）
	assert_eq(st.gold, 0)                                 # 金幣不變
	assert_signal_not_emitted(ov, "transacted")
	assert_string_contains(ov._panel.text, "金幣不足")   # 面板回饋
