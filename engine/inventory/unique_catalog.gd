class_name UniqueCatalog
extends Object

# 傳說專屬物件。mods 為固定值。base_id 必須存在於 base 池。
const _U := {
	"dawnblade": {"name": "弐光之刃", "base_id": "steel_blade", "min_ilvl": 45,
		"mods": {ItemStat.S.ATTACK: 18, ItemStat.S.MIGHT: 8, ItemStat.S.LUCK: 5},
		"on_hit": {"kind": StatusEffect.Kind.BURN, "potency": 6, "duration": 3, "chance": 0.5}},
	"bulwark_of_ages": {"name": "萬古壁壘", "base_id": "plate_armor", "min_ilvl": 50,
		"mods": {ItemStat.S.ARMOR: 20, ItemStat.S.ENDURANCE: 8, ItemStat.S.HP_MAX: 30}},
	"whisperwind": {"name": "耳語之風", "base_id": "short_sword", "min_ilvl": 20,
		"mods": {ItemStat.S.ATTACK: 9, ItemStat.S.SPEED: 8, ItemStat.S.ACCURACY: 6}},
}

static func entry(id: String) -> Dictionary:
	return _U.get(id, {})

static func eligible(ilvl: int) -> Array:
	var out: Array = []
	for id in _U:
		if int(_U[id]["min_ilvl"]) <= ilvl:
			out.append(id)
	return out
