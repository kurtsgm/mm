class_name SpellDef
extends Resource

enum School { ARCANE = 0, DIVINE = 1 }
enum Target { SINGLE_ENEMY = 0, ALL_ENEMIES = 1, SINGLE_ALLY = 2, ALL_ALLIES = 3 }
enum Effect { DAMAGE = 0, HEAL = 1, REVIVE = 2, STATUS = 3, TELEPORT = 4, RECALL = 5 }
enum ScaleStat { NONE = 0, MIGHT = 1, INTELLECT = 2, PERSONALITY = 3, ENDURANCE = 4, SPEED = 5, ACCURACY = 6, LUCK = 7, LEVEL = 8 }
enum Element { PHYSICAL = 0, FIRE = 1, COLD = 2, ELECTRIC = 3, POISON = 4, MAGIC = 5 }

@export var id: String = ""
@export var display_name: String = ""
@export var school: int = School.ARCANE
@export var sp_cost: int = 0
@export var gold_cost: int = 0
@export var target: int = Target.SINGLE_ENEMY
@export var effect: int = Effect.DAMAGE
@export var power: int = 0
@export var scale_stat: int = ScaleStat.NONE
@export var scale_per_point: float = 0.0
@export var element: int = Element.MAGIC
@export var status_stat: int = 0       # 僅 STAT_MOD 用（對應 StatusEffect.Stat）
@export var status_amount: int = 0
@export var status_duration: int = 0
@export var status_kind: int = 0       # StatusEffect.Kind（預設 STAT_MOD）
@export var status_potency: int = 0    # 僅 DoT 用
@export var status_chance: float = 1.0

func is_combat_usable() -> bool:
	return effect == Effect.DAMAGE or effect == Effect.HEAL or effect == Effect.REVIVE or effect == Effect.STATUS

func is_field_usable() -> bool:
	return effect == Effect.HEAL or effect == Effect.REVIVE or effect == Effect.TELEPORT or effect == Effect.RECALL
