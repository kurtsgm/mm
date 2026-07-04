class_name ItemStat
extends Object

# 詞綴與裝備可加成的屬性域。順序即序列化用的 enum int。
enum S { ATTACK, ARMOR, MIGHT, INTELLECT, PERSONALITY, ENDURANCE, SPEED, ACCURACY, LUCK, HP_MAX, SP_MAX }

const _NAMES := ["attack", "armor", "might", "intellect", "personality", "endurance", "speed", "accuracy", "luck", "hp_max", "sp_max"]

static func to_name(stat: int) -> String:
	if stat < 0 or stat >= _NAMES.size():
		return ""
	return _NAMES[stat]

static func from_name(name: String) -> int:
	return _NAMES.find(name)   # 找不到回 -1
