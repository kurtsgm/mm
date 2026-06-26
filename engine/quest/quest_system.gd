class_name QuestSystem
extends Object
# 任務階段推進——「狀態式」純函式：目標是否達成由對持久玩家狀態查詢決定，
# 與事件順序無關、天生可追認（接取前就做完的也算）。所有函式回傳「新 state」、不變更輸入。
# state 形狀：{ "status": "active"|"done", "stage": int }
# q（duck-typed 查詢）：q.kill_count(id)->int、q.item_count(id)->int、q.is_explored(map_id, cell)->bool

static func initial_state() -> Dictionary:
	return {"status": "active", "stage": 0}

static func is_complete(state) -> bool:
	return String(state.get("status", "")) == "done"

# 非 talk 的階段是否已被持久狀態滿足。talk 不自動滿足（須對話推進）。
static func is_stage_satisfied(stage: Dictionary, q) -> bool:
	match String(stage.get("type", "")):
		"kill":
			return int(q.kill_count(String(stage.get("monster", "")))) >= int(stage.get("count", 1))
		"collect":
			return int(q.item_count(String(stage.get("item", "")))) >= int(stage.get("count", 1))
		"reach":
			return bool(q.is_explored(String(stage.get("map", "")), stage.get("pos", Vector2i(-1, -1))))
		_:  # talk 等：不自動滿足
			return false

# 當前（非 talk）階段已滿足就連續進階；停在未滿足 / talk / done。回新 state、不變更輸入。
static func catch_up(def, state, q) -> Dictionary:
	var ns: Dictionary = state.duplicate()
	while String(ns.get("status", "")) == "active":
		var st: Dictionary = def.stage(int(ns["stage"]))
		if String(st.get("type", "")) == "talk":
			break
		if not is_stage_satisfied(st, q):
			break
		ns = _advance(def, ns)
	return ns

# 對話推進：當前是 talk → 進一階，再 catch_up（後續若已滿足一併追認）。
static func advance_talk(def, state, q) -> Dictionary:
	if String(state.get("status", "")) != "active":
		return state.duplicate()
	var st: Dictionary = def.stage(int(state.get("stage", 0)))
	if String(st.get("type", "")) != "talk":
		return state.duplicate()
	return catch_up(def, _advance(def, state.duplicate()), q)

# 推進到下一階段；超過末端 → done、stage 釘在 stage_count。
static func _advance(def, ns: Dictionary) -> Dictionary:
	ns["stage"] = int(ns["stage"]) + 1
	if int(ns["stage"]) >= def.stage_count():
		ns["status"] = "done"
		ns["stage"] = def.stage_count()
	return ns
