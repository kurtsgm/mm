class_name ItemEffects
extends Object

# 對指定 Character 套用一個消耗品 ItemDef 的效果，回傳事件字串陣列；無效則回空陣列。
# 純邏輯：只改 Character 欄位，夾在上限內。呼叫端依「回傳非空」決定是否扣背包。

static func can_use(item: ItemDef, target: Character) -> bool:
	if item == null or target == null or not item.is_consumable():
		return false
	if item.revive:
		return not target.is_conscious()   # 復活類：對昏迷/死亡才有意義
	if not item.cure_kinds.is_empty() and _has_curable(item, target):
		return true
	if not target.is_alive():
		return false                        # 非復活類對死亡無效
	var hp_room := item.heal_hp > 0 and target.hp < target.hp_max
	var sp_room := item.heal_sp > 0 and target.sp < target.sp_max
	return hp_room or sp_room

static func apply(item: ItemDef, target: Character) -> Array:
	var events: Array = []
	if not can_use(item, target):
		return events
	if item.revive:
		target.condition = Character.Condition.OK
		target.hp = maxi(1, mini(item.heal_hp, target.hp_max))
		events.append("%s 被救醒了。" % target.name)
		return events
	if not item.cure_kinds.is_empty():
		var kept: Array[StatusEffect] = []
		var removed := 0
		for s in target.statuses:
			if item.cure_kinds.has(s.kind):
				removed += 1
			else:
				kept.append(s)
		if removed > 0:
			target.statuses = kept
			events.append("%s 的異常狀態解除了。" % target.name)
		return events
	if item.heal_hp > 0:
		var before := target.hp
		target.hp = mini(target.hp_max, target.hp + item.heal_hp)
		events.append("%s 回復了 %d 點 HP。" % [target.name, target.hp - before])
	if item.heal_sp > 0:
		var before_sp := target.sp
		target.sp = mini(target.sp_max, target.sp + item.heal_sp)
		events.append("%s 回復了 %d 點 SP。" % [target.name, target.sp - before_sp])
	return events

static func _has_curable(item: ItemDef, target: Character) -> bool:
	for s in target.statuses:
		if item.cure_kinds.has(s.kind):
			return true
	return false
