class_name Leveling
extends Object

const XP_A := 40
const XP_B_PCT := 140   # 指數 1.4（climb-to-100 初值；Task 7 調定）

# 從 level 升到 level+1 所需經驗
static func xp_for_level(level: int) -> int:
	return int(round(XP_A * pow(level, XP_B_PCT / 100.0)))

# 累加經驗並就地套用升級（依職業成長）；回傳升級次數
static func grant_xp(c: Character, amount: int) -> int:
	c.experience += amount
	var levels := 0
	while c.experience >= xp_for_level(c.level):
		c.experience -= xp_for_level(c.level)
		c.level += 1
		var g := ClassCatalog.growth(c.char_class)
		c.hp_max += g["hp_max"]
		c.sp_max += g["sp_max"]
		c.might += g["might"]
		c.intellect += g["intellect"]
		c.personality += g["personality"]
		c.endurance += g["endurance"]
		c.speed += g["speed"]
		c.accuracy += g["accuracy"]
		c.luck += g["luck"]
		levels += 1
	if levels > 0:
		c.hp = c.hp_max
		c.sp = c.sp_max
	return levels
