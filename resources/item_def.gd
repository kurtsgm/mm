class_name ItemDef
extends Resource

enum Category { WEAPON = 0, ARMOR = 1, ACCESSORY = 2, CONSUMABLE = 3 }

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D = null
@export var category: int = Category.WEAPON
@export var attack: int = 0
@export var armor: int = 0
@export var heal_hp: int = 0
@export var heal_sp: int = 0
@export var revive: bool = false
@export var cure_kinds: Array = []   # 要解除的 StatusEffect.Kind
@export var value: int = 0
@export var stackable: bool = false
@export var min_level: int = 1       # 這個 base 最早出現的怪物等級（程序掉落）
@export var max_level: int = 999     # 最晚出現（強力 base 設窄帶，如 50~60）
@export var drop_weight: int = 0     # 進程序掉落池的權重；0 = 不參與程序掉落
@export var slot_tag: String = ""    # 細分（sword/axe…）；V1 預留、不使用

func is_equippable() -> bool:
	return category == Category.WEAPON or category == Category.ARMOR or category == Category.ACCESSORY

func is_consumable() -> bool:
	return category == Category.CONSUMABLE
