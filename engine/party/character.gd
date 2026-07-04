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

# ItemStat.S → 對應的 Character base 欄位值
func _base_attr(stat: int) -> int:
	match stat:
		ItemStat.S.MIGHT: return might
		ItemStat.S.INTELLECT: return intellect
		ItemStat.S.PERSONALITY: return personality
		ItemStat.S.ENDURANCE: return endurance
		ItemStat.S.SPEED: return speed
		ItemStat.S.ACCURACY: return accuracy
		ItemStat.S.LUCK: return luck
		ItemStat.S.HP_MAX: return hp_max
		ItemStat.S.SP_MAX: return sp_max
		_: return 0

func effective_attr(stat: int) -> int:
	return _base_attr(stat) + equipment.total_stat(stat)

func effective_speed() -> int:
	return effective_attr(ItemStat.S.SPEED)

func effective_luck() -> int:
	return effective_attr(ItemStat.S.LUCK)

func effective_hp_max() -> int:
	return hp_max + equipment.total_stat(ItemStat.S.HP_MAX)

func effective_sp_max() -> int:
	return sp_max + equipment.total_stat(ItemStat.S.SP_MAX)

func attack_power() -> int:
	return effective_attr(ItemStat.S.MIGHT) + equipment.total_attack() + StatusRules.stat_total(statuses, StatusEffect.Stat.ATTACK)

func armor_value() -> int:
	return equipment.total_armor() + StatusRules.stat_total(statuses, StatusEffect.Stat.ARMOR) + CombatFormulas.defense_from_endurance(effective_attr(ItemStat.S.ENDURANCE))

func effective_accuracy() -> int:
	return effective_attr(ItemStat.S.ACCURACY) + StatusRules.stat_total(statuses, StatusEffect.Stat.ACCURACY)
