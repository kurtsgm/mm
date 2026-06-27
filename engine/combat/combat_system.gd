class_name CombatSystem
extends RefCounted

enum Result { ONGOING, VICTORY, DEFEAT, FLED }

var party: Party
var monsters: Array[Monster] = []

var _rng: RandomNumberGenerator
var _order: Array = []
var _index: int = 0
var _result: int = Result.ONGOING
var _defending: Dictionary = {}   # Character -> true（本輪防禦中）
var _pending_events: Array = []   # 回合外（DoT/起訖）事件，由 CombatLayer drain 進 log

func _init(p: Party, mons: Array[Monster], rng: RandomNumberGenerator) -> void:
	party = p
	monsters = mons
	_rng = rng
	_strip_party_to_persisting()   # 帶毒進場、清掉殘留非持久
	_start_round()

func result() -> int:
	return _result

func is_over() -> bool:
	return _result != Result.ONGOING

# 目前行動者（Character 或 Monster）；戰鬥結束回 null
func current_combatant():
	if is_over() or _index >= _order.size():
		return null
	return _order[_index]

func is_party_turn() -> bool:
	var c = current_combatant()
	return c != null and c is Character

func living_monsters() -> Array[Monster]:
	var out: Array[Monster] = []
	for m in monsters:
		if m.is_alive():
			out.append(m)
	return out

# 隊員攻擊 living_monsters() 中第 monster_index 隻
func party_attack(monster_index: int) -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Character):
		return events
	var living := living_monsters()
	if monster_index < 0 or monster_index >= living.size():
		return events
	var target: Monster = living[monster_index]
	if CombatFormulas.roll_hit(actor.effective_accuracy(), target.speed, _rng):
		var dmg := CombatFormulas.roll_damage(actor.attack_power(), target.effective_armor(), false, _rng)
		target.hp -= dmg
		target.statuses = StatusRules.cleared_on_hit(target.statuses)
		events.append("%s 攻擊 %s，造成 %d 傷害。" % [actor.name, target.name, dmg])
		if not target.is_alive():
			events.append("%s 被擊倒了！" % target.name)
	else:
		events.append("%s 攻擊 %s，但沒打中。" % [actor.name, target.name])
	_advance()
	return events

# 怪物 AI：攻擊隨機清醒隊員
func monster_act() -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Monster):
		return events
	var targets: Array = []
	for m in party.members:
		if m.is_conscious():
			targets.append(m)
	if targets.is_empty():
		_advance()
		return events
	var target: Character = targets[_rng.randi_range(0, targets.size() - 1)]
	var defending := _defending.has(target)
	if CombatFormulas.roll_hit(actor.effective_accuracy(), target.speed, _rng):
		var dmg := CombatFormulas.roll_damage(actor.effective_attack(), target.armor_value(), defending, _rng)
		target.take_damage(dmg)
		target.statuses = StatusRules.cleared_on_hit(target.statuses)
		if actor.inflict_kind >= 0 and _rng.randf() <= actor.inflict_chance:
			target.statuses.append(StatusCatalog.from_data(actor.inflict_kind, -1, 0, actor.inflict_potency, actor.inflict_duration))
			events.append("%s 陷入了異常狀態！" % target.name)
		events.append("%s 攻擊 %s，造成 %d 傷害。" % [actor.name, target.name, dmg])
		if target.hp <= 0:
			target.hp = 0
			target.condition = Character.Condition.UNCONSCIOUS
			events.append("%s 倒下了！" % target.name)
	else:
		events.append("%s 攻擊 %s，但沒打中。" % [actor.name, target.name])
	_advance()
	return events

func party_defend() -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Character):
		return events
	_defending[actor] = true
	events.append("%s 採取防禦姿態。" % actor.name)
	_advance()
	return events

func party_run() -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Character):
		return events
	if _rng.randi_range(1, 100) <= flee_chance():
		_result = Result.FLED
		_strip_party_to_persisting()
		events.append("隊伍成功逃離了戰鬥。")
	else:
		events.append("逃跑失敗！")
		_advance()
	return events

# 若目前行動者被 sleep/paralysis 阻止 → 產生訊息並前進，回傳事件；否則回 []。
# 僅在有 incapacitating 狀態時擲骰，避免擾動既有命中/傷害 RNG 序列。
func try_skip_turn() -> Array:
	var events: Array = []
	var actor = current_combatant()
	if actor == null:
		return events
	if not StatusRules.incapacitating(actor.statuses):
		return events
	if StatusRules.prevents_action(actor.statuses, _rng.randf()):
		events.append("%s %s，無法行動。" % [actor.name, StatusRules.incap_reason(actor.statuses)])
		_advance()
	return events

# 隊員施放已解析的 SpellDef。target_index：單體時為敵/友索引；AoE 時忽略。
func party_cast(spell: SpellDef, target_index: int) -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Character):
		return events
	if spell == null or not spell.is_combat_usable():
		return events
	if not actor.known_spells.has(spell.id):
		events.append("%s 還不會 %s。" % [actor.name, spell.display_name])
		return events
	if actor.sp < spell.sp_cost:
		events.append("%s 的 SP 不足。" % actor.name)
		return events
	actor.sp -= spell.sp_cost
	match spell.effect:
		SpellDef.Effect.DAMAGE:
			events.append_array(_cast_damage(spell, actor, target_index))
		SpellDef.Effect.HEAL, SpellDef.Effect.REVIVE:
			events.append_array(_cast_support(spell, actor, target_index))
		SpellDef.Effect.STATUS:
			events.append_array(_cast_status(spell, target_index))
	_advance()
	return events

# 隊員對 target_index 隊友使用消耗品。效果套用成功（events 非空）才前進回合。
# 不碰背包：扣除由呼叫端（CombatLayer）依「events 非空」決定，維持本類對 GameState 解耦。
func party_use_item(item: ItemDef, target_index: int) -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Character):
		return events
	if target_index < 0 or target_index >= party.members.size():
		return events
	var target: Character = party.members[target_index]
	events = ItemEffects.apply(item, target)
	if events.is_empty():
		return events
	_advance()
	return events

func _cast_damage(spell: SpellDef, caster: Character, target_index: int) -> Array:
	var events: Array = []
	for t in _enemy_targets(spell, target_index):
		var base := SpellPower.magnitude(spell, caster)
		var rolled := CombatFormulas.roll_spell_damage(base, _rng)
		var dmg := Resistance.apply(rolled, t.resist_for(spell.element))
		t.hp -= dmg
		t.statuses = StatusRules.cleared_on_hit(t.statuses)
		events.append("%s 對 %s 施放 %s，造成 %d 傷害。" % [caster.name, t.name, spell.display_name, dmg])
		if not t.is_alive():
			events.append("%s 被擊倒了！" % t.name)
	return events

func _cast_support(spell: SpellDef, caster: Character, target_index: int) -> Array:
	var events: Array = []
	for t in _ally_targets(spell, target_index):
		events.append_array(SpellEffects.apply(spell, caster, t))
	return events

func _cast_status(spell: SpellDef, target_index: int) -> Array:
	var events: Array = []
	var to_allies := spell.target == SpellDef.Target.SINGLE_ALLY or spell.target == SpellDef.Target.ALL_ALLIES
	var targets: Array = _ally_targets(spell, target_index) if to_allies else _enemy_targets(spell, target_index)
	for t in targets:
		if _rng.randf() <= spell.status_chance:
			t.statuses.append(StatusCatalog.from_data(spell.status_kind, spell.status_stat, spell.status_amount, spell.status_potency, spell.status_duration))
			events.append("%s 受到了 %s 的效果。" % [t.name, spell.display_name])
		else:
			events.append("%s 抵抗了 %s。" % [t.name, spell.display_name])
	return events

func is_defending(c) -> bool:
	return _defending.has(c)

func flee_chance() -> int:
	return clampi(50 + (_avg_party_speed() - _avg_monster_speed()) * 3, 10, 95)

# --- internal ---

func drain_events() -> Array:
	var out := _pending_events
	_pending_events = []
	return out

func _strip_party_to_persisting() -> void:
	for m in party.members:
		m.statuses = StatusRules.keep_persisting(m.statuses)

func _tick_statuses() -> void:
	for c in party.members:
		_dot_and_decay(c, true)
	for mon in monsters:
		_dot_and_decay(mon, false)

# 先 DoT（可致死）再 decay remaining。is_char 區分倒下處理。
func _dot_and_decay(combatant, is_char: bool) -> void:
	var dmg := StatusRules.turn_damage(combatant.statuses)
	if dmg > 0:
		if is_char:
			combatant.take_damage(dmg)
			_pending_events.append("%s 受到 %d 點持續傷害。" % [combatant.name, dmg])
			if combatant.hp <= 0:
				combatant.hp = 0
				combatant.condition = Character.Condition.UNCONSCIOUS
				_pending_events.append("%s 倒下了！" % combatant.name)
		else:
			combatant.hp = maxi(0, combatant.hp - dmg)
			_pending_events.append("%s 受到 %d 點持續傷害。" % [combatant.name, dmg])
			if not combatant.is_alive():
				_pending_events.append("%s 被擊倒了！" % combatant.name)
	_decay(combatant.statuses)

func _decay(statuses: Array) -> void:
	var i := statuses.size() - 1
	while i >= 0:
		statuses[i].remaining -= 1
		if statuses[i].remaining <= 0:
			statuses.remove_at(i)
		i -= 1

func _start_round() -> void:
	_defending.clear()
	_tick_statuses()
	var combatants: Array = []
	for m in party.members:
		if m.is_conscious():
			combatants.append(m)
	for mon in monsters:
		if mon.is_alive():
			combatants.append(mon)
	_order = TurnOrder.build(combatants)
	_index = 0
	_skip_invalid()
	_check_end()

func _advance() -> void:
	_check_end()
	if is_over():
		return
	_index += 1
	_skip_invalid()
	if _index >= _order.size():
		_start_round()

# 跳過已死亡怪物 / 已昏迷隊員（本輪稍早被擊倒者）
func _skip_invalid() -> void:
	while _index < _order.size():
		var c = _order[_index]
		if c is Monster and not c.is_alive():
			_index += 1
		elif c is Character and not c.is_conscious():
			_index += 1
		else:
			break

func _check_end() -> void:
	if _result != Result.ONGOING:
		return
	if living_monsters().is_empty():
		_result = Result.VICTORY
		_strip_party_to_persisting()
	elif party.is_wiped():
		_result = Result.DEFEAT

func _avg_party_speed() -> float:
	var total := 0
	var n := 0
	for m in party.members:
		if m.is_conscious():
			total += m.speed
			n += 1
	return float(total) / n if n > 0 else 0.0

func _avg_monster_speed() -> float:
	var living := living_monsters()
	if living.is_empty():
		return 0.0
	var total := 0
	for m in living:
		total += m.speed
	return float(total) / living.size()

func _enemy_targets(spell: SpellDef, target_index: int) -> Array:
	var living := living_monsters()
	if spell.target == SpellDef.Target.ALL_ENEMIES:
		return living
	if target_index < 0 or target_index >= living.size():
		return []
	return [living[target_index]]

func _ally_targets(spell: SpellDef, target_index: int) -> Array:
	if spell.target == SpellDef.Target.ALL_ALLIES:
		return party.members
	if target_index < 0 or target_index >= party.members.size():
		return []
	return [party.members[target_index]]
