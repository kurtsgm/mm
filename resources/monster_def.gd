class_name MonsterDef
extends Resource

@export var display_name: String = ""
@export var sprite: Texture2D = null
@export var level: int = 1
@export var hp_max: int = 1
@export var might: int = 0
@export var armor: int = 0
@export var speed: int = 0
@export var accuracy: int = 0
@export var luck: int = 0
@export var xp_reward: int = 0
@export var gold_reward: int = 0
@export var drop_item_id: String = ""
@export var drop_chance: float = 0.0
@export var resistances: Dictionary = {}   # Element(int) -> int 百分比（可負）
