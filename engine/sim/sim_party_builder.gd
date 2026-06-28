class_name SimPartyBuilder
extends Object
# 依目標等級從 Party.create_default() 的 roster 生出模擬用隊伍：
# 全員設為同一 level、屬性由 catalog.stats_at_level 衍生、全清醒滿血滿 SP、依職業帶起始法術。
# catalog 預設 ClassCatalog；Phase D 可傳同介面（stats_at_level）的替代表試候選數字。

const _CLASS_SPELLS := {
	"Sorcerer": ["spark", "flame_wave", "weaken"],
	"Cleric": ["heal", "revive", "bless"],
	"Paladin": ["heal"],
}

static func build(level: int, catalog = ClassCatalog) -> Party:
	var p := Party.create_default()
	for m in p.members:
		m.level = level
		var s: Dictionary = catalog.stats_at_level(m.char_class, level)
		m.might = s["might"]
		m.intellect = s["intellect"]
		m.personality = s["personality"]
		m.endurance = s["endurance"]
		m.speed = s["speed"]
		m.accuracy = s["accuracy"]
		m.luck = s["luck"]
		m.hp_max = s["hp_max"]
		m.sp_max = s["sp_max"]
		m.hp = m.hp_max
		m.sp = m.sp_max
		m.condition = Character.Condition.OK
		m.statuses = []
	seed_class_spells(p)
	return p

static func seed_class_spells(party: Party) -> void:
	for m in party.members:
		m.known_spells = _spells_for(m.char_class)

static func _spells_for(char_class: String) -> Array[String]:
	var out: Array[String] = []
	if _CLASS_SPELLS.has(char_class):
		for id in _CLASS_SPELLS[char_class]:
			out.append(String(id))
	return out
