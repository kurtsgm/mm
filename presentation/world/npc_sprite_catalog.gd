class_name NpcSpriteCatalog
extends Object

# npc_id → 兩態貼圖路徑（idle/idle2）。鏡射 MonsterSpriteCatalog 的「id→資源路徑對照表」慣例。
# 未註冊／缺檔 → null（由 NpcLayer fallback 成 placeholder）；idle2 缺則退回微幅晃動。
# 內容期逐 NPC 填入；貼圖為去背 alpha PNG（同畫風、同框同比例，見 docs/art-style-guide.md）。
const _SPRITES := {}

static func textures_for(npc_id: String) -> Dictionary:
	if not _SPRITES.has(npc_id):
		return {"idle": null, "idle2": null}
	return _resolve_spec(_SPRITES[npc_id])

# 純路徑解析：路徑非空且存在則 load，否則 null。
static func _resolve_spec(spec: Dictionary) -> Dictionary:
	var out := {"idle": null, "idle2": null}
	for key in out:
		var path := String(spec.get(key, ""))
		if path != "" and ResourceLoader.exists(path):
			out[key] = load(path)
	return out
