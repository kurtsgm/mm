class_name NpcSpriteCatalog
extends Object

# npc_id → 兩態貼圖路徑（idle/idle2）。鏡射 MonsterSpriteCatalog 的「id→資源路徑對照表」慣例。
# 未註冊／缺檔 → null（由 NpcLayer fallback 成 placeholder）；正式單幀使用貼地呼吸。
# 貼圖為去背 alpha WebP（同畫風、同框同比例，見 docs/art-style-guide.md）。
const _SPRITES := {
	"margo": {
		"idle": "res://content/npcs/margo/idle.webp",
		"name": "瑪歌",
		"role": "療者",
		"height": 1.72,
		"foot_ratio": 0.985,
		"shadow_width": 0.9,
	},
}

# 素材尺寸與展示資料集中在此；地圖只引用 sprite id。
static func presentation_for(npc_id: String) -> Dictionary:
	return _SPRITES.get(npc_id, {})

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
