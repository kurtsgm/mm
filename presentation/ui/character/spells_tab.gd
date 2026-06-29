class_name CharacterSpellsTab
extends Object

# 角色已習得法術的顯示。野外可用（治療/復活/傳送/回城）可施放；其餘標戰鬥限定。

const _EFFECT_LABEL := {
	SpellDef.Effect.DAMAGE: "傷害",
	SpellDef.Effect.HEAL: "治療",
	SpellDef.Effect.REVIVE: "復活",
	SpellDef.Effect.STATUS: "異常",
	SpellDef.Effect.TELEPORT: "傳送",
	SpellDef.Effect.RECALL: "回城",
}

static func rows(caster: Character) -> Array:
	var out: Array = []
	if caster == null:
		return out
	for id in caster.known_spells:
		var s := SpellBook.get_spell(String(id))
		if s == null:
			continue
		out.append({"spell": s, "field": s.is_field_usable()})
	return out

static func lines(rows_: Array, cursor: int) -> Array:
	var out: Array = []
	if rows_.is_empty():
		out.append("（未習得法術）")
		return out
	for i in rows_.size():
		var s: SpellDef = rows_[i]["spell"]
		var mark := "> " if i == cursor else "  "
		var tag := "" if bool(rows_[i]["field"]) else "  （戰鬥中可用）"
		out.append("%s%s   SP%d   %s%s" % [mark, s.display_name, s.sp_cost, _effect_label(s.effect), tag])
	return out

static func _effect_label(effect: int) -> String:
	return _EFFECT_LABEL.get(effect, "?")
