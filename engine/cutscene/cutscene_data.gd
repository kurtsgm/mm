class_name CutsceneData
extends RefCounted
# 演出序列（step 陣列）。畸形（缺 type / 型別必填缺失 / steps 非陣列）→ parse 回 null。
# 純資料：不做跨檔驗證（dialogue/image/sfx id 是否存在留執行期各自容錯）。

var id: String = ""
var steps: Array = []

const _FADE_TO := ["black", "clear"]
const _AUDIO_OP := ["sfx", "bgm", "stop"]

static func parse(raw) -> CutsceneData:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var raw_steps = raw.get("steps", null)
	if typeof(raw_steps) != TYPE_ARRAY:
		return null
	var parsed: Array = []
	for rs in raw_steps:
		var step := _parse_step(rs)
		if step.is_empty():
			return null
		parsed.append(step)
	var d := CutsceneData.new()
	d.id = String(raw.get("id", ""))
	d.steps = parsed
	return d

# 回補完預設的 step；畸形回 {}（呼叫端視為 parse 失敗）。
static func _parse_step(rs) -> Dictionary:
	if typeof(rs) != TYPE_DICTIONARY:
		return {}
	var t := String(rs.get("type", ""))
	match t:
		"fade":
			var to := String(rs.get("to", "black"))
			if not _FADE_TO.has(to):
				return {}
			return { "type": t, "to": to, "duration": float(rs.get("duration", 0.5)) }
		"title_card":
			if not rs.has("title"):
				return {}
			return { "type": t, "title": String(rs["title"]),
				"subtitle": String(rs.get("subtitle", "")), "hold": float(rs.get("hold", 2.5)) }
		"cg":
			if not rs.has("image"):
				return {}
			return { "type": t, "image": String(rs["image"]), "hold": float(rs.get("hold", 0.0)) }
		"dialogue":
			if not rs.has("dialogue"):
				return {}
			return { "type": t, "dialogue": String(rs["dialogue"]) }
		"shake":
			return { "type": t, "intensity": float(rs.get("intensity", 5.0)),
				"duration": float(rs.get("duration", 0.4)) }
		"audio":
			var op := String(rs.get("op", ""))
			if not _AUDIO_OP.has(op):
				return {}
			return { "type": t, "op": op, "id": String(rs.get("id", "")) }
		"wait":
			return { "type": t, "duration": float(rs.get("duration", 1.0)) }
		"effects":
			var eff = rs.get("effects", [])
			if typeof(eff) != TYPE_ARRAY:
				return {}
			return { "type": t, "effects": eff }
		_:
			return {}
