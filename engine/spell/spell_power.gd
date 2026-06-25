class_name SpellPower
extends Object

# 威力 scaling 樣板：全系統算法術主純量（傷害/治療量）的唯一入口。
# scale_stat == NONE → 純固定 power；否則 power + floor(scale_per_point * 該屬性)。

static func magnitude(spell: SpellDef, caster: Character) -> int:
	if spell.scale_stat == SpellDef.ScaleStat.NONE:
		return spell.power
	return spell.power + int(floor(spell.scale_per_point * _read_stat(caster, spell.scale_stat)))

static func _read_stat(caster: Character, stat: int) -> int:
	match stat:
		SpellDef.ScaleStat.MIGHT: return caster.might
		SpellDef.ScaleStat.INTELLECT: return caster.intellect
		SpellDef.ScaleStat.PERSONALITY: return caster.personality
		SpellDef.ScaleStat.ENDURANCE: return caster.endurance
		SpellDef.ScaleStat.SPEED: return caster.speed
		SpellDef.ScaleStat.ACCURACY: return caster.accuracy
		SpellDef.ScaleStat.LUCK: return caster.luck
		SpellDef.ScaleStat.LEVEL: return caster.level
	return 0
