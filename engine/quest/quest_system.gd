class_name QuestSystem
extends Object
# 任務階段推進的純函式。所有函式回傳「新 state dict」、不變更輸入。
# state 形狀：{ "status": "active"|"done", "stage": int, "count": int }

static func initial_state() -> Dictionary:
	return {"status": "active", "stage": 0, "count": 0}

static func is_complete(state) -> bool:
	return String(state.get("status", "")) == "done"

static func notify_kill(def, state, monster_id: String) -> Dictionary:
	var st := _cur(def, state, "kill")
	if st.is_empty():
		return state.duplicate()
	if String(st.get("monster", "")) != monster_id:
		return state.duplicate()
	var ns: Dictionary = state.duplicate()
	ns["count"] = int(ns["count"]) + 1
	if int(ns["count"]) >= int(st.get("count", 1)):
		return _advance(def, ns)
	return ns

static func notify_enter(def, state, map_id: String, pos: Vector2i) -> Dictionary:
	var st := _cur(def, state, "reach")
	if st.is_empty():
		return state.duplicate()
	if String(st.get("map", "")) == map_id and st.get("pos", Vector2i(-1, -1)) == pos:
		return _advance(def, state.duplicate())
	return state.duplicate()

static func notify_advance(def, state) -> Dictionary:
	var st := _cur(def, state, "talk")
	if st.is_empty():
		return state.duplicate()
	return _advance(def, state.duplicate())

static func check_collect(def, state, have_count: Callable) -> Dictionary:
	var st := _cur(def, state, "collect")
	if st.is_empty():
		return state.duplicate()
	var have := int(have_count.call(String(st.get("item", "")))) if have_count.is_valid() else 0
	if have >= int(st.get("count", 1)):
		return _advance(def, state.duplicate())
	return state.duplicate()

# 回傳當前階段 dict（須為 active 且型別相符），否則 {}。
static func _cur(def, state, want_type: String) -> Dictionary:
	if String(state.get("status", "")) != "active":
		return {}
	var st: Dictionary = def.stage(int(state.get("stage", 0)))
	if String(st.get("type", "")) != want_type:
		return {}
	return st

# 推進到下一階段（count 歸 0）；超過末端 → done、stage 釘在 stage_count。
static func _advance(def, ns: Dictionary) -> Dictionary:
	ns["stage"] = int(ns["stage"]) + 1
	ns["count"] = 0
	if int(ns["stage"]) >= def.stage_count():
		ns["status"] = "done"
		ns["stage"] = def.stage_count()
	return ns
