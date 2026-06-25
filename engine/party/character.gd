class_name Character
extends RefCounted

enum Condition { OK = 0, UNCONSCIOUS = 1, DEAD = 2 }

var name: String
var char_class: String
var level: int
var hp: int
var hp_max: int
var sp: int
var sp_max: int
var might: int
var intellect: int
var personality: int
var endurance: int
var speed: int
var accuracy: int
var luck: int
var condition: int = Condition.OK
var experience: int = 0
var equipment: Equipment = Equipment.new()

func is_alive() -> bool:
	return condition != Condition.DEAD

func is_conscious() -> bool:
	return condition == Condition.OK

func attack_power() -> int:
	return might + equipment.total_attack()

func armor_value() -> int:
	return equipment.total_armor()
