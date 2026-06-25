class_name StatusMods
extends Object

# 把一串 StatusEffect 中、指定 stat 的修正量加總。雙方 effective 取值器共用。
static func sum(statuses: Array, stat: int) -> int:
	var total := 0
	for s in statuses:
		if s.stat == stat:
			total += s.amount
	return total
