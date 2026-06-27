class_name Monster
extends RefCounted

var monster_id: String
var name: String
var level: int
var hp: int
var hp_max: int
var might: int
var armor: int
var speed: int
var accuracy: int
var luck: int
var xp_reward: int
var gold_reward: int
var drop_item_id: String = ""
var drop_chance: float = 0.0
var statuses: Array[StatusEffect] = []
var resistances: Dictionary = {}
var inflict_kind: int = -1
var inflict_potency: int = 0
var inflict_duration: int = 0
var inflict_chance: float = 0.0

func is_alive() -> bool:
	return hp > 0

func resist_for(element: int) -> int:
	return resistances.get(element, 0)

func effective_attack() -> int:
	return might + StatusRules.stat_total(statuses, StatusEffect.Stat.ATTACK)

func effective_armor() -> int:
	return armor + StatusRules.stat_total(statuses, StatusEffect.Stat.ARMOR)

func effective_accuracy() -> int:
	return accuracy + StatusRules.stat_total(statuses, StatusEffect.Stat.ACCURACY)

static func from_def(def: MonsterDef) -> Monster:
	var m := Monster.new()
	m.monster_id = def.id
	m.name = def.display_name
	m.level = def.level
	m.hp = def.hp_max
	m.hp_max = def.hp_max
	m.might = def.might
	m.armor = def.armor
	m.speed = def.speed
	m.accuracy = def.accuracy
	m.luck = def.luck
	m.xp_reward = def.xp_reward
	m.gold_reward = def.gold_reward
	m.drop_item_id = def.drop_item_id
	m.drop_chance = def.drop_chance
	m.resistances = def.resistances.duplicate()
	m.inflict_kind = def.inflict_kind
	m.inflict_potency = def.inflict_potency
	m.inflict_duration = def.inflict_duration
	m.inflict_chance = def.inflict_chance
	return m
