class_name CombatSystem
extends RefCounted

enum Result { ONGOING, VICTORY, DEFEAT, FLED }

var party: Party
var monsters: Array[Monster] = []

var _rng: RandomNumberGenerator
var _order: Array = []
var _index: int = 0
var _result: int = Result.ONGOING

func _init(p: Party, mons: Array[Monster], rng: RandomNumberGenerator) -> void:
	party = p
	monsters = mons
	_rng = rng
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
	if CombatFormulas.roll_hit(actor.accuracy, target.speed, _rng):
		var dmg := CombatFormulas.roll_damage(actor.might, target.armor, false, _rng)
		target.hp -= dmg
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
	var defending := false
	if CombatFormulas.roll_hit(actor.accuracy, target.speed, _rng):
		var dmg := CombatFormulas.roll_damage(actor.might, 0, defending, _rng)
		target.hp -= dmg
		events.append("%s 攻擊 %s，造成 %d 傷害。" % [actor.name, target.name, dmg])
		if target.hp <= 0:
			target.hp = 0
			target.condition = Character.Condition.UNCONSCIOUS
			events.append("%s 倒下了！" % target.name)
	else:
		events.append("%s 攻擊 %s，但沒打中。" % [actor.name, target.name])
	_advance()
	return events

# --- internal ---

func _start_round() -> void:
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
	if living_monsters().is_empty():
		_result = Result.VICTORY
	elif party.is_wiped():
		_result = Result.DEFEAT
