class_name AffixCatalog
extends Object

# 詞綴常數表。mods 值為 [min,max]，roll 時取區間整數。高階詞綴用較高 min_ilvl 分層。
# stat 鍵用 ItemStat.S（int）。武器詞綴可帶 on_hit；防具詞綴可帶 resist。
const PREFIX := 0
const SUFFIX := 1

# 為簡潔，applies_to 用 ItemDef.Category：WEAPON=0 ARMOR=1 ACCESSORY=2
const _A := {
	# ---- 前綴（PREFIX）----
	"sharp":   {"name": "鋒利的", "kind": PREFIX, "applies_to": [0], "min_ilvl": 1,  "mods": {ItemStat.S.ATTACK: [2, 5]}},
	"heavy":   {"name": "沉重的", "kind": PREFIX, "applies_to": [0], "min_ilvl": 8,  "mods": {ItemStat.S.ATTACK: [4, 9]}},
	"cruel":   {"name": "殘暴的", "kind": PREFIX, "applies_to": [0], "min_ilvl": 30, "mods": {ItemStat.S.ATTACK: [8, 15], ItemStat.S.LUCK: [1, 4]}},
	"sturdy":  {"name": "堅固的", "kind": PREFIX, "applies_to": [1], "min_ilvl": 1,  "mods": {ItemStat.S.ARMOR: [2, 4]}},
	"plated":  {"name": "鑲甲的", "kind": PREFIX, "applies_to": [1], "min_ilvl": 20, "mods": {ItemStat.S.ARMOR: [5, 10]}},
	"blazing": {"name": "燃焰的", "kind": PREFIX, "applies_to": [0], "min_ilvl": 12, "mods": {}, "on_hit": {"kind": StatusEffect.Kind.BURN, "potency": 3, "duration": 3, "chance": 0.35}},
	"venom":   {"name": "淬毒的", "kind": PREFIX, "applies_to": [0], "min_ilvl": 6,  "mods": {}, "on_hit": {"kind": StatusEffect.Kind.POISON, "potency": 2, "duration": 3, "chance": 0.35}},
	# ---- 後綴（SUFFIX）----
	"of_the_bear": {"name": "·熊之力", "kind": SUFFIX, "applies_to": [0, 1, 2], "min_ilvl": 1,  "mods": {ItemStat.S.MIGHT: [2, 6]}},
	"of_haste":    {"name": "·神速",   "kind": SUFFIX, "applies_to": [0, 1, 2], "min_ilvl": 4,  "mods": {ItemStat.S.SPEED: [1, 4]}},
	"of_the_eagle":{"name": "·鷹眼",   "kind": SUFFIX, "applies_to": [0, 2],    "min_ilvl": 4,  "mods": {ItemStat.S.ACCURACY: [2, 5]}},
	"of_fortune":  {"name": "·幸運",   "kind": SUFFIX, "applies_to": [0, 1, 2], "min_ilvl": 10, "mods": {ItemStat.S.LUCK: [2, 6]}},
	"of_vigor":    {"name": "·活力",   "kind": SUFFIX, "applies_to": [1, 2],    "min_ilvl": 8,  "mods": {ItemStat.S.HP_MAX: [6, 15]}},
	"of_the_mind": {"name": "·心智",   "kind": SUFFIX, "applies_to": [2],       "min_ilvl": 8,  "mods": {ItemStat.S.INTELLECT: [2, 6], ItemStat.S.SP_MAX: [3, 8]}},
	"of_warding":  {"name": "·守護",   "kind": SUFFIX, "applies_to": [1, 2],    "min_ilvl": 14, "mods": {}, "resist": {}},  # resist 元素於 Phase 7 補
}

static func entry(id: String) -> Dictionary:
	return _A.get(id, {})

static func name_of(id: String) -> String:
	return String(_A.get(id, {}).get("name", id))

static func eligible(category: int, ilvl: int, kind: int) -> Array:
	var out: Array = []
	for id in _A:
		var e: Dictionary = _A[id]
		if int(e["kind"]) != kind:
			continue
		if not (e["applies_to"] as Array).has(category):
			continue
		if int(e["min_ilvl"]) > ilvl:
			continue
		out.append(id)
	return out

# 回傳 {ItemStat.S(int): rolled_int}
static func roll_mods(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {}
	var e: Dictionary = _A.get(id, {})
	var mods: Dictionary = e.get("mods", {})
	for stat in mods:
		var rng_pair: Array = mods[stat]
		out[stat] = rng.randi_range(int(rng_pair[0]), int(rng_pair[1]))
	return out
