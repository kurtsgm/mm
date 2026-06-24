class_name Leveling
extends Object

const HP_PER_LEVEL := 5
const SP_PER_LEVEL := 2

# 從 level 升到 level+1 所需經驗（placeholder 曲線）
static func xp_for_level(level: int) -> int:
	return level * 100

# 累加經驗並就地套用升級；回傳升級次數
static func grant_xp(c: Character, amount: int) -> int:
	c.experience += amount
	var levels := 0
	while c.experience >= xp_for_level(c.level):
		c.experience -= xp_for_level(c.level)
		c.level += 1
		c.hp_max += HP_PER_LEVEL
		c.sp_max += SP_PER_LEVEL
		levels += 1
	if levels > 0:
		c.hp = c.hp_max
		c.sp = c.sp_max
	return levels
