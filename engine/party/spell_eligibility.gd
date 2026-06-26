class_name SpellEligibility
extends Object

# char_class 字串 → 可施 SpellDef.School 清單；未列到 → 不可施任何法術（安全預設）。
# 平衡/內容決定，集中此處，日後可改成資料檔。
const _CLASS_SCHOOLS := {
	"Sorcerer": [SpellDef.School.ARCANE],
	"Cleric": [SpellDef.School.DIVINE],
	"Paladin": [SpellDef.School.DIVINE],
}

static func schools_for_class(char_class: String) -> Array:
	return _CLASS_SCHOOLS.get(char_class, [])

# 回 { ok:bool, reason:String }；reason ∈ "ok"|"already_known"|"wrong_school"。
static func can_learn(character, spell: SpellDef) -> Dictionary:
	if character.known_spells.has(spell.id):
		return {"ok": false, "reason": "already_known"}
	if not schools_for_class(character.char_class).has(spell.school):
		return {"ok": false, "reason": "wrong_school"}
	return {"ok": true, "reason": "ok"}
