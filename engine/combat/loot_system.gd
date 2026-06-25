class_name LootSystem
extends Object

# 從一組怪物擲掉落，回傳掉落道具 id 陣列。RNG 注入以利可重現/測試。
static func roll_drops(monsters: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for m in monsters:
		if m.drop_item_id != "" and rng.randf() < m.drop_chance:
			out.append(m.drop_item_id)
	return out
