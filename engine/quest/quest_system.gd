class_name QuestSystem
extends Object
# 任務階段推進——「狀態式」純函式：目標是否達成由對持久玩家狀態查詢決定，
# 與事件順序無關、天生可追認（接取前就做完的也算）。所有函式回傳「新 state」、不變更輸入。
# state 形狀：{ "status": "active"|"done", "stage": int }
# q（duck-typed 查詢）：q.kill_count(id)->int、q.item_count(id)->int。
# reach 不走 q（不是狀態式）——改事件式：踏入「該圖+該格」當下由 advance_reach 推進（精確、跨地圖）。

static func initial_state() -> Dictionary:
	return {"status": "active", "stage": 0}

static func is_complete(state) -> bool:
	return String(state.get("status", "")) == "done"

# 狀態式階段（kill/collect）是否已被持久狀態滿足。reach（事件式）與 talk（對話）不在此自動滿足。
static func is_stage_satisfied(stage: Dictionary, q) -> bool:
	match String(stage.get("type", "")):
		"kill":
			return int(q.kill_count(String(stage.get("monster", "")))) >= int(stage.get("count", 1))
		"collect":
			return int(q.item_count(String(stage.get("item", "")))) >= int(stage.get("count", 1))
		_:  # reach（事件式）/ talk（對話）：不自動滿足
			return false

# 狀態式階段（kill/collect）已滿足就連續進階；停在未滿足 / reach / talk / done。回新 state、不變更輸入。
static func catch_up(def, state, q) -> Dictionary:
	var ns: Dictionary = state.duplicate()
	while String(ns.get("status", "")) == "active":
		var st: Dictionary = def.stage(int(ns["stage"]))
		if not is_stage_satisfied(st, q):  # reach/talk 永遠 false → 停在這
			break
		ns = _advance(def, ns)
	return ns

# 對話推進：當前是 talk → 進一階，再 catch_up（後續狀態式階段一併追認）。
static func advance_talk(def, state, q) -> Dictionary:
	if String(state.get("status", "")) != "active":
		return state.duplicate()
	var st: Dictionary = def.stage(int(state.get("stage", 0)))
	if String(st.get("type", "")) != "talk":
		return state.duplicate()
	return catch_up(def, _advance(def, state.duplicate()), q)

# 進入事件推進：當前是 reach 且 (map,pos) 相符 → 進一階，再 catch_up。精確格、跨地圖。
static func advance_reach(def, state, map_id: String, pos: Vector2i, q) -> Dictionary:
	if String(state.get("status", "")) != "active":
		return state.duplicate()
	var st: Dictionary = def.stage(int(state.get("stage", 0)))
	if String(st.get("type", "")) != "reach":
		return state.duplicate()
	if String(st.get("map", "")) == map_id and st.get("pos", Vector2i(-1, -1)) == pos:
		return catch_up(def, _advance(def, state.duplicate()), q)
	return state.duplicate()

# 推進到下一階段；超過末端 → done、stage 釘在 stage_count。
static func _advance(def, ns: Dictionary) -> Dictionary:
	ns["stage"] = int(ns["stage"]) + 1
	if int(ns["stage"]) >= def.stage_count():
		ns["status"] = "done"
		ns["stage"] = def.stage_count()
	return ns
