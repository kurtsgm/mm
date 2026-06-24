class_name EncounterSystem
extends Object

# 把 MonsterDef 清單映成 Monster 執行實例組。骨架期不做隨機變化。
static func build_group(defs: Array[MonsterDef]) -> Array[Monster]:
	var out: Array[Monster] = []
	for def in defs:
		out.append(Monster.from_def(def))
	return out
