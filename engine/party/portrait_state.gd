class_name PortraitState
extends RefCounted
# 由角色「持久狀態」推導頭像臉（不含戰鬥中瞬間的受擊閃臉）。純邏輯、可測。

enum Face { OK, HURT, UNCONSCIOUS, DEAD }

const HURT_RATIO := 0.25

static func for_character(c: Character) -> int:
	if c.condition == Character.Condition.DEAD:
		return Face.DEAD
	if c.condition == Character.Condition.UNCONSCIOUS:
		return Face.UNCONSCIOUS
	if c.hp_max > 0 and float(c.hp) <= float(c.hp_max) * HURT_RATIO:
		return Face.HURT
	return Face.OK
