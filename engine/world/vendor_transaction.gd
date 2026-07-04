class_name VendorTransaction
extends Object

# 純函式商店交易。ctx 需暴露 gold:int(可讀寫) 與 inventory:Inventory。
# 各函式回傳 { ok:bool, reason:String, events:Array }；ok 時就地套用變更。
# 不碰 GameState/不發訊息（訊息由 events 帶回，呼叫端推 message_log）。

static func buy_goods(ctx, item: ItemDef) -> Dictionary:
	if ctx.gold < item.value:
		return {"ok": false, "reason": "no_gold", "events": []}
	ctx.gold -= item.value
	ctx.inventory.add(item.id, 1)
	return {"ok": true, "reason": "ok", "events": ["買下 %s（-%d 金）" % [item.display_name, item.value]]}

static func sell_goods(ctx, item: ItemDef, sell_factor: float) -> Dictionary:
	if not ctx.inventory.has(item.id):
		return {"ok": false, "reason": "not_owned", "events": []}
	var price := int(floor(item.value * sell_factor))
	ctx.inventory.remove(item.id, 1)
	ctx.gold += price
	return {"ok": true, "reason": "ok", "events": ["賣出 %s（+%d 金）" % [item.display_name, price]]}

# --- 裝備實例（ItemInstance）買賣 ---
# 消耗品走 buy_goods/sell_goods（以 id 計數）；裝備走這裡（生成/移除 ItemInstance）。

# 生成一件基礎裝備實例：COMMON 品質、ilvl 1、無詞綴。
static func make_base_instance(base_id: String) -> ItemInstance:
	var it := ItemInstance.new()
	it.base_id = base_id
	it.quality = Quality.Q.COMMON
	it.ilvl = 1
	return it

# 買基礎裝備：售價＝base ItemDef.value（經 base_resolver 解析）；成功則扣金、加實例進背包。
static func buy_equipment(ctx, base_id: String) -> Dictionary:
	var it := make_base_instance(base_id)
	var def := it.base_def()
	var cost: int = def.value if def != null else 0
	if ctx.gold < cost:
		return {"ok": false, "reason": "no_gold", "events": []}
	ctx.gold -= cost
	ctx.inventory.add_instance(it)
	return {"ok": true, "reason": "ok", "events": ["買下 %s（-%d 金）" % [it.display_name(), cost]]}

# 賣裝備實例：依 sell_value()（含品質倍率）給金、移出背包；不在背包則失敗。
static func sell_equipment(ctx, inst: ItemInstance) -> Dictionary:
	if not ctx.inventory.instances().has(inst):
		return {"ok": false, "reason": "not_owned", "events": []}
	var price := inst.sell_value()
	ctx.inventory.remove_instance(inst)
	ctx.gold += price
	return {"ok": true, "reason": "ok", "events": ["賣出 %s（+%d 金）" % [inst.display_name(), price]]}

static func learn_spell(ctx, spell: SpellDef, character) -> Dictionary:
	var elig: Dictionary = SpellEligibility.can_learn(character, spell)
	if not elig["ok"]:
		return {"ok": false, "reason": elig["reason"], "events": []}
	if ctx.gold < spell.gold_cost:
		return {"ok": false, "reason": "no_gold", "events": []}
	ctx.gold -= spell.gold_cost
	character.known_spells.append(spell.id)
	return {"ok": true, "reason": "ok", "events": ["%s 習得 %s（-%d 金）" % [character.name, spell.display_name, spell.gold_cost]]}

static func buy_service(ctx, offer: Dictionary, targets: Array) -> Dictionary:
	var cost := int(offer.get("cost", 0))
	if ctx.gold < cost:
		return {"ok": false, "reason": "no_gold", "events": []}
	var applied := _apply_effect(String(offer.get("effect", "")), targets)
	if applied.is_empty():
		return {"ok": false, "reason": "invalid_target", "events": []}
	ctx.gold -= cost
	var events: Array = ["%s（-%d 金）" % [String(offer.get("name", "服務")), cost]]
	events.append_array(applied)
	return {"ok": true, "reason": "ok", "events": events}

# 對 targets 套效果，回傳事件訊息（空 = 無一生效 → 呼叫端視為失敗）。
static func _apply_effect(effect: String, targets: Array) -> Array:
	var events: Array = []
	for t in targets:
		match effect:
			"revive":
				if t.condition != Character.Condition.OK:
					t.condition = Character.Condition.OK
					t.hp = maxi(t.hp, 1)
					events.append("%s 被救醒了。" % t.name)
			"heal_full":
				if t.condition != Character.Condition.DEAD:
					t.hp = t.effective_hp_max()
					if t.condition == Character.Condition.UNCONSCIOUS:
						t.condition = Character.Condition.OK
					t.statuses.clear()   # 全補一併清除狀態異常
					events.append("%s 回復滿血。" % t.name)
			"rest":
				if t.condition != Character.Condition.DEAD:
					t.hp = t.effective_hp_max()
					t.sp = t.effective_sp_max()
					if t.condition == Character.Condition.UNCONSCIOUS:
						t.condition = Character.Condition.OK
					t.statuses.clear()   # 休息一併清除狀態異常
					events.append("%s 休息完畢。" % t.name)
	return events
