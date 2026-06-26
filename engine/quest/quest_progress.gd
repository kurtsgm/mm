class_name QuestProgress
extends Object
# 任務日誌/訊息列文字（純）。kill/collect 顯示計數；reach/talk 只顯示描述。

static func stage_line(def, state, have_count: Callable) -> String:
	if String(state.get("status", "")) == "done":
		return "已完成"
	var st: Dictionary = def.stage(int(state.get("stage", 0)))
	var desc := String(st.get("desc", ""))
	match String(st.get("type", "")):
		"kill":
			return "%s %d/%d" % [desc, int(state.get("count", 0)), int(st.get("count", 1))]
		"collect":
			var have := int(have_count.call(String(st.get("item", "")))) if have_count.is_valid() else 0
			return "%s %d/%d" % [desc, have, int(st.get("count", 1))]
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
