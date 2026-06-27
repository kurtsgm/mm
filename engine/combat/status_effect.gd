class_name StatusEffect
extends RefCounted

# 統一效果：stat-mod 增益/減益（STAT_MOD）與行為型異常（POISON/BURN/SLEEP/PARALYSIS/SILENCE）。
# 由 StatusCatalog 工廠建構；行為解讀在 StatusRules。POISON 會帶出戰鬥（見 StatusRules.persists_overworld）。
enum Stat { ACCURACY = 0, ARMOR = 1, ATTACK = 2 }
enum Kind { STAT_MOD = 0, POISON = 1, BURN = 2, SLEEP = 3, PARALYSIS = 4, SILENCE = 5 }

var kind: int = Kind.STAT_MOD
var remaining: int = 0    # 剩餘回合（戰鬥）；地表中毒倒數也用它
var stat: int = -1        # 僅 STAT_MOD：作用的 Stat（否則 -1）
var amount: int = 0       # 僅 STAT_MOD：stat 增減量
var potency: int = 0      # 僅 DoT（POISON/BURN）：每跳扣 HP

# 保留舊三參形式（kind 預設 STAT_MOD），不破壞既有 StatusEffect.new(stat, amount, remaining) 呼叫端。
func _init(stat_: int = -1, amount_: int = 0, remaining_: int = 0) -> void:
	stat = stat_
	amount = amount_
	remaining = remaining_
