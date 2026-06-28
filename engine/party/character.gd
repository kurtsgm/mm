class_name Character
extends RefCounted

enum Condition { OK = 0, UNCONSCIOUS = 1, DEAD = 2 }

var name: String
var char_class: String
var level: int
# HP/SP/condition 改動時 emit stats_changed → 讓 UI（隊伍卡）即時刷新，
# 不必等走下一格或關選單。治療術、喝藥水、扣 MP、復活都自動經過這個 hook。
var hp: int:
	set(value):
		if value == hp:
			return
		hp = value
		stats_changed.emit()
var hp_max: int
var sp: int:
	set(value):
		if value == sp:
			return
		sp = value
		stats_changed.emit()
var sp_max: int
var might: int
var intellect: int
var personality: int
var endurance: int
var speed: int
var accuracy: int
var luck: int
var condition: int = Condition.OK:
	set(value):
		if value == condition:
			return
		condition = value
		stats_changed.emit()
var experience: int = 0
var equipment: Equipment = Equipment.new()
var known_spells: Array[String] = []
var statuses: Array[StatusEffect] = []

signal damaged(amount: int)
signal stats_changed

func is_alive() -> bool:
	return condition != Condition.DEAD

func is_conscious() -> bool:
	return condition == Condition.OK

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	damaged.emit(amount)

func attack_power() -> int:
	return might + equipment.total_attack() + StatusRules.stat_total(statuses, StatusEffect.Stat.ATTACK)

func armor_value() -> int:
	return equipment.total_armor() + StatusRules.stat_total(statuses, StatusEffect.Stat.ARMOR) + CombatFormulas.defense_from_endurance(endurance)

func effective_accuracy() -> int:
	return accuracy + StatusRules.stat_total(statuses, StatusEffect.Stat.ACCURACY)
