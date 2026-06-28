class_name PartyCombatPolicy
extends Object
# 模擬用「中等啟發式」隊伍決策：復活 > 補血(<門檻) > 期望傷害最高的傷害法術 > 集火最低血怪。
# act() 直接呼叫 CombatSystem 的 party_* 方法（會自動 _advance）。v1 不防禦/不用道具/不逃跑。
# 目標索引慣例：ally 法術 target_index = party.members 索引；攻擊/傷害法術 = living_monsters() 索引。

const HEAL_THRESHOLD := 0.40

static func act(cs: CombatSystem) -> void:
	var actor = cs.current_combatant()
	if actor == null or not (actor is Character):
		return
	var living := cs.living_monsters()
	if living.is_empty():
		return
	# 1) 復活昏迷隊友
	var revive := _known_by_effect(actor, SpellDef.Effect.REVIVE)
	if revive != null and actor.sp >= revive.sp_cost:
		var ko := unconscious_ally_index(cs.party)
		if ko >= 0:
			cs.party_cast(revive, ko)
			return
	# 2) 補最低血（低於門檻）的清醒隊友
	var heal := _known_by_effect(actor, SpellDef.Effect.HEAL)
	if heal != null and actor.sp >= heal.sp_cost:
		var hurt := lowest_hurt_ally_index(cs.party, HEAL_THRESHOLD)
		if hurt >= 0:
			cs.party_cast(heal, hurt)
			return
	# 3) 放期望傷害最高的傷害法術
	var dmg := best_damage_spell(actor, living.size())
	if dmg != null:
		if dmg.target == SpellDef.Target.ALL_ENEMIES:
			cs.party_cast(dmg, 0)
		else:
			cs.party_cast(dmg, lowest_hp_monster_index(living))
		return
	# 4) 集火最低血怪
	cs.party_attack(lowest_hp_monster_index(living))

# --- 純 helper ---

static func lowest_hp_monster_index(living: Array) -> int:
	var best := 0
	for i in range(1, living.size()):
		if living[i].hp < living[best].hp:
			best = i
	return best

static func unconscious_ally_index(party: Party) -> int:
	for i in party.members.size():
		if party.members[i].condition == Character.Condition.UNCONSCIOUS:
			return i
	return -1

static func lowest_hurt_ally_index(party: Party, threshold: float) -> int:
	var best := -1
	var best_ratio := threshold
	for i in party.members.size():
		var m: Character = party.members[i]
		if not m.is_conscious() or m.hp_max <= 0:
			continue
		var ratio := float(m.hp) / float(m.hp_max)
		if ratio < best_ratio:
			best_ratio = ratio
			best = i
	return best

static func best_damage_spell(caster: Character, living_count: int) -> SpellDef:
	var best: SpellDef = null
	var best_exp := 0
	for id in caster.known_spells:
		var s := SpellBook.get_spell(id)
		if s == null or s.effect != SpellDef.Effect.DAMAGE or s.sp_cost > caster.sp:
			continue
		var mag := SpellPower.magnitude(s, caster)
		var exp_dmg := mag * living_count if s.target == SpellDef.Target.ALL_ENEMIES else mag
		if exp_dmg > best_exp:
			best_exp = exp_dmg
			best = s
	return best

static func _known_by_effect(caster: Character, effect: int) -> SpellDef:
	for id in caster.known_spells:
		var s := SpellBook.get_spell(id)
		if s != null and s.effect == effect:
			return s
	return null
