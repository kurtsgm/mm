class_name SimPartyBuilder
extends Object
# 依目標等級 + 可抽換成長模型，從 Party.create_default() 生出模擬用隊伍。
# 一律全清醒、滿血滿 SP、依職業帶起始法術（同 GameState._seed_starting_spells）。

const _CLASS_SPELLS := {
	"Sorcerer": ["spark", "flame_wave", "weaken"],
	"Cleric": ["heal", "revive", "bless"],
	"Paladin": ["heal"],
}

static func build(level: int, hp_per_level: int = Leveling.HP_PER_LEVEL, sp_per_level: int = Leveling.SP_PER_LEVEL) -> Party:
	var p := Party.create_default()
	for m in p.members:
		_set_level(m, level, hp_per_level, sp_per_level)
		m.condition = Character.Condition.OK
		m.statuses = []
		m.known_spells = _spells_for(m.char_class)
	return p

# 以成員預設等級 D 與 hp_max_D 反推 level-1 錨點，再依成長模型重算到目標 level。
# hp1 = hp_max_D - (D-1)*per；hp_max(L) = hp1 + (L-1)*per。L=D 時還原預設。
static func _set_level(c: Character, level: int, hp_per_level: int, sp_per_level: int) -> void:
	var hp1: int = c.hp_max - (c.level - 1) * hp_per_level
	var sp1: int = c.sp_max - (c.level - 1) * sp_per_level
	c.level = level
	c.hp_max = maxi(1, hp1 + (level - 1) * hp_per_level)
	c.sp_max = maxi(0, sp1 + (level - 1) * sp_per_level)
	c.hp = c.hp_max
	c.sp = c.sp_max

static func _spells_for(char_class: String) -> Array[String]:
	var out: Array[String] = []
	if _CLASS_SPELLS.has(char_class):
		for id in _CLASS_SPELLS[char_class]:
			out.append(String(id))
	return out
