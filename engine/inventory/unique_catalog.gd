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
	# --- 七大遺器（神器；神話階 fixed unique；排除隨機池，見 eligible）---
	"eternal_lamp": {"name": "不熄之燈", "base_id": "amulet_of_power", "min_ilvl": 35,
		"is_artifact": true, "set_id": "seven_relics",
		"mods": {ItemStat.S.LUCK: 10, ItemStat.S.INTELLECT: 6, ItemStat.S.SP_MAX: 20}},
	"genesis_casket": {"name": "造物之匣", "base_id": "iron_ring", "min_ilvl": 45,
		"is_artifact": true, "set_id": "seven_relics",
		"mods": {ItemStat.S.MIGHT: 8, ItemStat.S.ENDURANCE: 8, ItemStat.S.HP_MAX: 30}},
	"stasis_reliquary": {"name": "長眠之棺", "base_id": "lucky_charm", "min_ilvl": 45,
		"is_artifact": true, "set_id": "seven_relics",
		"mods": {ItemStat.S.ENDURANCE: 12, ItemStat.S.ARMOR: 8, ItemStat.S.HP_MAX: 40}},
	"wayfinder_astrolabe": {"name": "引路星盤", "base_id": "ring_of_kings", "min_ilvl": 35,
		"is_artifact": true, "set_id": "seven_relics",
		"mods": {ItemStat.S.ACCURACY: 12, ItemStat.S.SPEED: 12, ItemStat.S.LUCK: 8}},
	"starender_blade": {"name": "弒星之刃", "base_id": "dragonbone_sword", "min_ilvl": 65,
		"is_artifact": true, "set_id": "seven_relics",
		"mods": {ItemStat.S.ATTACK: 28, ItemStat.S.MIGHT: 12, ItemStat.S.ACCURACY: 8}},
	"choir_crown": {"name": "聖言之冕", "base_id": "amulet_of_power", "min_ilvl": 20,
		"is_artifact": true, "set_id": "seven_relics",
		"mods": {ItemStat.S.INTELLECT: 14, ItemStat.S.PERSONALITY: 10, ItemStat.S.SP_MAX: 30}},
	"aegis_field_core": {"name": "不破之壁", "base_id": "dragon_scale", "min_ilvl": 65,
		"is_artifact": true, "set_id": "seven_relics",
		"mods": {ItemStat.S.ARMOR: 24, ItemStat.S.ENDURANCE: 10, ItemStat.S.HP_MAX: 50}},
}

static func entry(id: String) -> Dictionary:
	return _U.get(id, {})

static func make(id: String, ilvl: int = -1) -> ItemInstance:
	var e := entry(id)
	if e.is_empty():
		return null
	var it := ItemInstance.new()
	it.unique_id = id
	it.base_id = String(e["base_id"])
	it.ilvl = ilvl if ilvl > 0 else int(e.get("min_ilvl", 1))
	it.quality = Quality.Q.MYTHIC if bool(e.get("is_artifact", false)) else Quality.Q.LEGENDARY
	return it

static func is_artifact(id: String) -> bool:
	return bool(entry(id).get("is_artifact", false))

static func artifacts() -> Array:
	var out: Array = []
	for id in _U:
		if bool(_U[id].get("is_artifact", false)):
			out.append(id)
	return out

static func eligible(ilvl: int) -> Array:
	var out: Array = []
	for id in _U:
		if bool(_U[id].get("is_artifact", false)):
			continue   # 神器只從固定來源進場，永不入隨機掉落池
		if int(_U[id]["min_ilvl"]) <= ilvl:
			out.append(id)
	return out
