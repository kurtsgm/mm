class_name QuestProgress
extends Object
# 任務日誌/訊息列文字（純）。kill/collect 顯示計數（夾住目標）；reach/talk 只顯示描述。
# q（duck-typed 查詢）：q.kill_count(id)->int、q.item_count(id)->int。

static func stage_line(def, state, q) -> String:
	if String(state.get("status", "")) == "done":
		return "已完成"
	var st: Dictionary = def.stage(int(state.get("stage", 0)))
	var desc := String(st.get("desc", ""))
	match String(st.get("type", "")):
		"kill":
			var nk := int(st.get("count", 1))
			return "%s %d/%d" % [desc, mini(int(q.kill_count(String(st.get("monster", "")))), nk), nk]
		"collect":
			var nc := int(st.get("count", 1))
			return "%s %d/%d" % [desc, mini(int(q.item_count(String(st.get("item", "")))), nc), nc]
		_:
			return desc

static func accepted_message(def) -> String:
	return "接下任務：%s" % def.title

static func completed_message(def) -> String:
	var parts: Array[String] = []
	var g := int(def.rewards.get("gold", 0))
	if g > 0:
		parts.append("%d 金幣" % g)
	for it in def.rewards.get("items", []):
		parts.append(String(it))
	var reward := ("，獎勵：" + "、".join(parts)) if not parts.is_empty() else ""
	return "任務完成：%s%s" % [def.title, reward]
