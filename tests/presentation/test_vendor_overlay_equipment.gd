extends GutTest

# 商店 UI 裝備買賣：賣掉落 ItemInstance（走 sell_equipment）、買可裝備 stock（走 buy_equipment）。
# base_resolver 用真 ItemCatalog（short_sword=WEAPON value30），before_all 裝、after_all 卸。

class FakeState:
	var gold: int = 0
	var inventory := Inventory.new()
	var party := FakeParty.new()

class FakeParty:
	var members: Array = []

func before_all():
	ItemCatalog.install_resolver()

func after_all():
	ItemInstance.base_resolver = Callable()

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev

func _overlay() -> VendorOverlay:
	var ov := VendorOverlay.new()
	add_child_autofree(ov)
	return ov

# 只賣裝備的店（stock 放可裝備 short_sword），sell_factor 只影響消耗品。
func _goods() -> Dictionary:
	return {"id": "s", "kind": "goods", "name": "武具店", "sell_factor": 0.5,
			"stock": ["short_sword"]}

func _rare_sword() -> ItemInstance:
	var it := ItemInstance.new()
	it.base_id = "short_sword"
	it.quality = Quality.Q.RARE       # sell_value = round(30 * 3.5) = 105
	return it

# --- SELL：背包裝備實例出現在賣清單，Enter 賣掉走 sell_equipment ---
func test_sell_mode_lists_equipment_instance_with_sell_value():
	var st := FakeState.new()
	var inst := _rare_sword()
	st.inventory.add_instance(inst)
	var ov := _overlay()
	ov.open(_goods(), st)
	ov._unhandled_input(_key(KEY_TAB))      # 進賣模式
	var rows := ov._goods_rows()
	var found := {}
	for r in rows:
		if r.has("inst") and r["inst"] == inst:
			found = r
	assert_false(found.is_empty(), "賣清單應含該裝備實例")
	assert_eq(int(found["price"]), inst.sell_value())   # 全額 sell_value（品質倍率已含）
	assert_eq(int(found["price"]), 105)

func test_sell_equipment_enter_adds_gold_and_removes_instance():
	var st := FakeState.new()
	st.gold = 0
	var inst := _rare_sword()
	st.inventory.add_instance(inst)
	var ov := _overlay()
	ov.open(_goods(), st)
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_TAB))      # 進賣模式（cursor=0 指向唯一的裝備列）
	ov._unhandled_input(_key(KEY_ENTER))    # 賣掉
	assert_eq(st.gold, 105)                          # +sell_value
	assert_eq(st.inventory.instances().size(), 0)    # 實例已移出
	assert_signal_emitted(ov, "transacted")
	assert_eq(ov._goods_rows().size(), 0)            # 清單變空
	assert_true(ov._cursor >= 0)                     # 游標夾住未越界

# --- BUY：stock 的可裝備 base，Enter 買下應生成 ItemInstance（非消耗品堆疊）---
func test_buy_equipment_enter_creates_instance_not_stack():
	var st := FakeState.new()
	st.gold = 100
	var ov := _overlay()
	ov.open(_goods(), st)      # 預設 buy_mode=true，cursor=0 指向 short_sword
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_ENTER))
	assert_eq(st.inventory.instances().size(), 1)    # 生成裝備實例
	var inst: ItemInstance = st.inventory.instances()[0]
	assert_eq(inst.base_id, "short_sword")
	assert_eq(inst.quality, Quality.Q.COMMON)        # buy_equipment 給 COMMON
	assert_eq(st.inventory.count_of("short_sword"), 0)   # 不是塞進消耗品堆疊
	assert_eq(st.gold, 100 - 30)                     # 扣 base value
	assert_signal_emitted(ov, "transacted")
