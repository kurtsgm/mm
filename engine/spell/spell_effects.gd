class_name SpellEffects
extends Object

# 對指定 Character 套用 support 法術（HEAL/REVIVE），回事件字串陣列；無效回空。
# 純邏輯：只改 Character。治療量走 SpellPower（屬性 scaling）。戰鬥與野外共用。

static func can_cast(spell: SpellDef, caster: Character, target: Character) -> bool:
	if spell == null or caster == null or target == null:
		return false
	if spell.effect == SpellDef.Effect.REVIVE:
		return not target.is_conscious()       # 復活：對昏迷/死亡才有意義
	if spell.effect == SpellDef.Effect.HEAL:
		return target.is_alive() and target.hp < target.hp_max
	return false

static func apply(spell: SpellDef, caster: Character, target: Character) -> Array:
	var events: Array = []
	if not can_cast(spell, caster, target):
		return events
	var amount := SpellPower.magnitude(spell, caster)
	if spell.effect == SpellDef.Effect.REVIVE:
		target.condition = Character.Condition.OK
		target.hp = maxi(1, mini(amount, target.hp_max))
		events.append("%s 被救醒了。" % target.name)
		return events
	# HEAL
	var before := target.hp
	target.hp = mini(target.hp_max, target.hp + amount)
	events.append("%s 回復了 %d 點 HP。" % [target.name, target.hp - before])
	return events
