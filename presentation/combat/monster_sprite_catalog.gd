class_name MonsterSpriteCatalog
extends Object

# monster_id → 三態貼圖路徑（idle/attack/hurt）。鏡射 PortraitCatalog/DecorationCatalog 的
# 「id→資源路徑對照表」慣例。骨架期空表（無真美術，全怪 fallback 到 placeholder）；
# 之後逐怪填入，例如：
#   "fire_imp": {"idle": "res://content/monsters/sprites/fire_imp_idle.png",
#                "attack": "res://content/monsters/sprites/fire_imp_attack.png",
#                "hurt": "res://content/monsters/sprites/fire_imp_hurt.png"},
const _SPRITES := {
}

# 回 {idle,attack,hurt}，每項為 Texture2D 或 null（缺項/未註冊 → null，由呼叫端 fallback base）。
static func textures_for(monster_id: String) -> Dictionary:
	if not _SPRITES.has(monster_id):
		return {"idle": null, "attack": null, "hurt": null}
	return _resolve_spec(_SPRITES[monster_id])

# 純路徑解析：路徑非空且存在則 load，否則 null。
static func _resolve_spec(spec: Dictionary) -> Dictionary:
	var out := {"idle": null, "attack": null, "hurt": null}
	for key in out:
		var path := String(spec.get(key, ""))
		if path != "" and ResourceLoader.exists(path):
			out[key] = load(path)
	return out
