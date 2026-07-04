class_name LootSystem
extends Object

# tier → 未指定時的裝備掉落機率預設（由模擬器調校）
const _GEAR_DEFAULT := [0.06, 0.07, 0.08, 0.09, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15]

static func _gear_chance(m) -> float:
	if m.gear_drop_chance >= 0.0:
		return m.gear_drop_chance
	return _GEAR_DEFAULT[LootRoller.tier_for(m.level) - 1]

# 回傳 {item_ids: Array[String], instances: Array[ItemInstance]}
static func roll_drops(monsters: Array, source: int, bases: Array, rng: RandomNumberGenerator) -> Dictionary:
	var ids: Array = []
	var insts: Array = []
	for m in monsters:
		if m.drop_item_id != "" and rng.randf() < m.drop_chance:
			ids.append(m.drop_item_id)
		if rng.randf() < _gear_chance(m):
			var it := LootRoller.roll(bases, m.level, source, rng)
			if it != null:
				insts.append(it)
	return {"item_ids": ids, "instances": insts}
