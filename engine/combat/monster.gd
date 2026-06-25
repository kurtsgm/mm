class_name Monster
extends RefCounted

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

func is_alive() -> bool:
	return hp > 0

static func from_def(def: MonsterDef) -> Monster:
	var m := Monster.new()
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
	return m
