class_name FieldSpellAction
extends Object

static func validate(caster: Character, spell: SpellDef) -> ActionResult:
	if caster == null or spell == null or spell.sp_cost < 0:
		return ActionResult.failure(&"invalid_spell")
	if not caster.is_conscious():
		return ActionResult.failure(&"incapacitated", ["該角色目前無法施法。"])
	if not caster.known_spells.has(spell.id):
		return ActionResult.failure(&"not_known", ["尚未學會這個法術。"])
	if not spell.is_field_usable():
		return ActionResult.failure(&"wrong_mode")
	if caster.sp < spell.sp_cost:
		return ActionResult.failure(&"no_sp", ["%s 的 SP 不足。" % caster.name])
	return ActionResult.success()

static func cast(caster: Character, spell: SpellDef, targets: Array) -> ActionResult:
	var result := validate(caster, spell)
	if not result.ok:
		return result
	if spell.effect not in [SpellDef.Effect.HEAL, SpellDef.Effect.REVIVE]:
		return ActionResult.failure(&"unsupported_effect")
	var valid: Array[Character] = []
	for target in targets:
		if target is Character and SpellEffects.can_cast(spell, caster, target) and not valid.has(target):
			valid.append(target)
	if valid.is_empty() or (spell.target == SpellDef.Target.SINGLE_ALLY and valid.size() != 1):
		return ActionResult.failure(&"invalid_target", ["沒有可生效的施法對象。"])
	# Validation is complete; commit synchronously, with no signals/await between cost and effects.
	caster.sp -= spell.sp_cost
	var events: Array = []
	for target in valid:
		events.append_array(SpellEffects.apply(spell, caster, target))
	return ActionResult.success(events)
