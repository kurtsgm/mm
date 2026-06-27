class_name QuestFlow
extends Object
# 模擬把一條任務從接取驅動到完成（happy path）：每階段觸發對應 GameState 事件。
# 給 /check-quest 與迴歸測試用。回 { completed:bool }。

static func simulate(gs, def, qid: String) -> Dictionary:
	gs.accept_quest(qid)
	var guard := 0
	while gs.is_quest_active(qid) and guard < 50:
		guard += 1
		var idx = gs.quest_stage(qid)
		_drive(gs, def, qid, def.stage(idx))
		if gs.is_quest_active(qid) and gs.quest_stage(qid) == idx:
			break   # 驅動沒推進 → 卡住，跳出（completed 會是 false）
	return {"completed": gs.is_quest_done(qid)}

static func _drive(gs, def, qid: String, st: Dictionary) -> void:
	match String(st.get("type", "")):
		"kill":
			for t in st.get("targets", []):
				gs.notify_encounter_defeated(String(t))
		"collect":
			gs.inventory.add(String(st.get("item", "")), int(st.get("count", 1)))
			gs.refresh_collect()
		"reach":
			gs.notify_enter(String(st.get("map", "")), st.get("pos", Vector2i.ZERO))
		"talk":
			gs.advance_quest(qid)
