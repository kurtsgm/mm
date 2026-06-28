class_name ClassCatalog
extends Object
# 六職業 base（level-1）+ 每級成長的唯一真相來源。spec §4.1 初值，Phase D 調。
# 鍵：might/intellect/personality/endurance/speed/accuracy/luck/hp_max/sp_max。

const _KEYS := ["might", "intellect", "personality", "endurance", "speed", "accuracy", "luck", "hp_max", "sp_max"]

const _CLASSES := {
	"Knight": {
		"base": {"might": 16, "intellect": 8, "personality": 8, "endurance": 18, "speed": 11, "accuracy": 13, "luck": 9, "hp_max": 30, "sp_max": 0},
		"growth": {"hp_max": 6, "might": 1, "endurance": 1},
	},
	"Paladin": {
		"base": {"might": 14, "intellect": 10, "personality": 13, "endurance": 15, "speed": 11, "accuracy": 12, "luck": 10, "hp_max": 26, "sp_max": 8},
		"growth": {"hp_max": 5, "sp_max": 2, "might": 1, "personality": 1},
	},
	"Archer": {
		"base": {"might": 13, "intellect": 9, "personality": 9, "endurance": 12, "speed": 15, "accuracy": 16, "luck": 12, "hp_max": 22, "sp_max": 0},
		"growth": {"hp_max": 4, "accuracy": 1, "speed": 1},
	},
	"Cleric": {
		"base": {"might": 9, "intellect": 12, "personality": 16, "endurance": 11, "speed": 11, "accuracy": 11, "luck": 10, "hp_max": 20, "sp_max": 14},
		"growth": {"hp_max": 3, "sp_max": 3, "personality": 1},
	},
	"Sorcerer": {
		"base": {"might": 7, "intellect": 17, "personality": 11, "endurance": 8, "speed": 12, "accuracy": 11, "luck": 10, "hp_max": 14, "sp_max": 16},
		"growth": {"hp_max": 2, "sp_max": 3, "intellect": 1},
	},
	"Robber": {
		"base": {"might": 13, "intellect": 9, "personality": 9, "endurance": 12, "speed": 16, "accuracy": 13, "luck": 16, "hp_max": 22, "sp_max": 0},
		"growth": {"hp_max": 4, "speed": 1, "luck": 1},
	},
}

static func has_class(c: String) -> bool:
	return _CLASSES.has(c)

static func all_classes() -> Array:
	return _CLASSES.keys()

static func _zero() -> Dictionary:
	var d := {}
	for k in _KEYS:
		d[k] = 0
	return d

static func base_stats(c: String) -> Dictionary:
	if not _CLASSES.has(c):
		return _zero()
	var out := _zero()
	for k in _CLASSES[c]["base"]:
		out[k] = _CLASSES[c]["base"][k]
	return out

static func growth(c: String) -> Dictionary:
	if not _CLASSES.has(c):
		return _zero()
	var out := _zero()
	for k in _CLASSES[c]["growth"]:
		out[k] = _CLASSES[c]["growth"][k]
	return out

static func stats_at_level(c: String, level: int) -> Dictionary:
	var base := base_stats(c)
	var grow := growth(c)
	var out := {}
	for k in _KEYS:
		out[k] = base[k] + (level - 1) * grow[k]
	return out
