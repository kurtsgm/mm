class_name CombatFormulas
extends Object

# placeholder 戰鬥公式（內容期再平衡）。所有隨機走注入的 RandomNumberGenerator 以利可重現。

const HIT_BASE := 60
const HIT_PER_POINT := 2
const HIT_MIN := 5
const HIT_MAX := 95

const DEF_PER_ENDURANCE := 4

static func defense_from_endurance(endurance: int) -> int:
	return endurance / DEF_PER_ENDURANCE

static func hit_chance(accuracy: int, target_speed: int) -> int:
	return clampi(HIT_BASE + (accuracy - target_speed) * HIT_PER_POINT, HIT_MIN, HIT_MAX)

static func roll_hit(accuracy: int, target_speed: int, rng: RandomNumberGenerator) -> bool:
	return rng.randi_range(1, 100) <= hit_chance(accuracy, target_speed)

static func roll_damage(might: int, armor: int, defending: bool, rng: RandomNumberGenerator) -> int:
	var base: int = maxi(1, might - armor)
	var dmg: int = rng.randi_range(base, base * 2)
	if defending:
		dmg = maxi(1, dmg / 2)
	return dmg

static func roll_spell_damage(base: int, rng: RandomNumberGenerator) -> int:
	var b: int = maxi(1, base)
	return rng.randi_range(b, b + b / 2)
