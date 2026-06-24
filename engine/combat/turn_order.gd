class_name TurnOrder
extends Object

# 依 speed 降序；speed 相同時保持輸入順序（穩定）→ 決定性。
static func build(combatants: Array) -> Array:
	var indexed: Array = []
	for i in combatants.size():
		indexed.append({"c": combatants[i], "i": i})
	indexed.sort_custom(func(a, b):
		if a["c"].speed != b["c"].speed:
			return a["c"].speed > b["c"].speed
		return a["i"] < b["i"])
	var out: Array = []
	for entry in indexed:
		out.append(entry["c"])
	return out
