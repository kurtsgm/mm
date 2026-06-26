class_name QuestDef
extends RefCounted
# 任務定義（線性階段鏈）。畸形（空 stages / 未知 stage type / 缺必要參數）→ parse 回 null。

var id: String = ""
var title: String = ""
var stages: Array = []        # 正規化後的 objective dict 陣列
var rewards: Dictionary = {}  # { gold:int, items:Array[String] }

static func parse(raw: Dictionary) -> QuestDef:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var raw_stages = raw.get("stages", null)
	if typeof(raw_stages) != TYPE_ARRAY or raw_stages.is_empty():
		return null
	var parsed: Array = []
	for rs in raw_stages:
		var st := _parse_stage(rs)
		if st.is_empty():
			return null
		parsed.append(st)
	var d := QuestDef.new()
	d.id = String(raw.get("id", ""))
	d.title = String(raw.get("title", ""))
	d.stages = parsed
	d.rewards = _parse_rewards(raw.get("rewards", {}))
	return d

func stage_count() -> int:
	return stages.size()

func stage(i: int) -> Dictionary:
	if i < 0 or i >= stages.size():
		return {}
	return stages[i]

# 單一 stage 正規化；違規 → {}（空 = 失敗）。
static func _parse_stage(rs) -> Dictionary:
	if typeof(rs) != TYPE_DICTIONARY or not rs.has("type"):
		return {}
	var desc := String(rs.get("desc", ""))
	match String(rs["type"]):
		"reach":
			if not rs.has("map") or not rs.has("pos"):
				return {}
			var pos = _parse_pos(rs["pos"])
			if pos == null:
				return {}
			return {"type": "reach", "map": String(rs["map"]), "pos": pos, "desc": desc}
		"kill":
			if not rs.has("monster") or not _is_pos_int(rs.get("count", null)):
				return {}
			return {"type": "kill", "monster": String(rs["monster"]), "count": int(rs["count"]), "desc": desc}
		"collect":
			if not rs.has("item") or not _is_pos_int(rs.get("count", null)):
				return {}
			return {"type": "collect", "item": String(rs["item"]), "count": int(rs["count"]), "desc": desc}
		"talk":
			return {"type": "talk", "desc": desc}
		_:
			return {}

static func _parse_rewards(r) -> Dictionary:
	var out := {"gold": 0, "items": []}
	if typeof(r) != TYPE_DICTIONARY:
		return out
	out["gold"] = int(r.get("gold", 0))
	var items: Array = []
	if r.get("items", null) is Array:
		for it in r["items"]:
			items.append(String(it))
	out["items"] = items
	return out

static func _parse_pos(v):
	if typeof(v) != TYPE_ARRAY or v.size() < 2:
		return null
	if not (_is_num(v[0]) and _is_num(v[1])):
		return null
	return Vector2i(int(v[0]), int(v[1]))

static func _is_num(x) -> bool:
	return typeof(x) == TYPE_INT or typeof(x) == TYPE_FLOAT

static func _is_pos_int(x) -> bool:
	return _is_num(x) and int(x) > 0
