class_name StatusEffect
extends RefCounted

# 戰鬥期間的計時 stat 修正（增益/減益）。不入存檔。
enum Stat { ACCURACY = 0, ARMOR = 1, ATTACK = 2 }

var stat: int
var amount: int
var remaining: int   # 剩餘回合數

func _init(stat_: int, amount_: int, remaining_: int) -> void:
	stat = stat_
	amount = amount_
	remaining = remaining_
