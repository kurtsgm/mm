class_name CombatActions
extends Object

# 當前行動者的可用行動清單。攻/防/逃恆有；施法只在有可戰鬥法術、道具只在有可用消耗品時出現。
# 純函式：呼叫端先算好兩個布林（避免本函式依賴 SpellBook/Inventory）。
static func available(has_combat_spell: bool, has_usable_item: bool) -> Array:
	var out: Array = ["attack", "defend"]
	if has_combat_spell:
		out.append("spell")
	if has_usable_item:
		out.append("item")
	out.append("run")
	return out
