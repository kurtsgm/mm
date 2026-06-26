class_name ChestLoot
extends Object

# 純函式：把寶箱道具加進背包、回傳 gold 與實際發出的 item id 清單。
# 不碰 GameState、不發訊息（金幣加總與訊息由 main 端負責），保持可測。
static func grant(chest: Dictionary, inventory: Inventory) -> Dictionary:
	var granted: Array[String] = []
	var items = chest.get("items", [])
	if items is Array:
		for id in items:
			var sid := String(id)
			if sid == "":
				continue
			inventory.add(sid, 1)
			granted.append(sid)
	return {"gold": int(chest.get("gold", 0)), "items": granted}
