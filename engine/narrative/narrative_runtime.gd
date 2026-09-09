class_name NarrativeRuntime
extends RefCounted

## Quest execution and story progress; no rendering, audio, or input ownership.
var _state

func _init(state) -> void:
	_state = state

func accept_quest(id: String) -> void:
	if _state.quests.has(id):
		return  # 已接/已完成，冪等
	var def = _state._quest_def(id)
	if def == null:
		return
	_state.quests[id] = QuestSystem.initial_state()
	_state.tracked_quest = id
	var msg := QuestProgress.accepted_message(def)
	_state.message_log.push(msg)
	_state.quest_event.emit(msg)
	_state.quests_changed.emit()
	_run_quest(id, "recheck")   # 接取追認：已完成的階段（殺過/撿過/到過）立即跳過、不卡死

func advance_quest(id: String) -> void:
	_run_quest(id, "talk")

func _run_quest(id: String, kind: String, a = null, b = null) -> void:
	if not _state.is_quest_active(id):
		return
	var def = _state._quest_def(id)
	if def == null:
		return
	var before: Dictionary = _state.quests[id]
	var after: Dictionary
	match kind:
		"talk":
			after = QuestSystem.advance_talk(def, before, _state)
		"enter":
			after = QuestSystem.advance_reach(def, before, String(a), b, _state)
		_:  # "recheck"
			after = QuestSystem.catch_up(def, before, _state)
	_commit_quest(id, def, before, after)

func _commit_quest(id: String, def, before: Dictionary, after: Dictionary) -> void:
	var changed: bool = after["status"] != before["status"] or after["stage"] != before["stage"]
	if not changed:
		return
	_state.quests[id] = after
	var text: String
	if String(after["status"]) == "done":
		_grant_quest_rewards(def)
		text = QuestProgress.completed_message(def)
		if _state.tracked_quest == id:
			_state.retrack()
	else:
		text = "任務更新：" + QuestProgress.stage_line(def, after, _state)
	_state.message_log.push(text)
	_state.quest_event.emit(text)
	_state.quests_changed.emit()

func _grant_quest_rewards(def) -> void:
	var g := int(def.rewards.get("gold", 0))
	if g > 0:
		_state.gold += g
	for it in def.rewards.get("items", []):
		_state.inventory.add(String(it), 1)
	var xp := int(def.rewards.get("xp", 0))
	if xp > 0:
		var leveled := false
		for m in _state.party.members:
			if m.is_conscious() and Leveling.grant_xp(m, xp) > 0:
				leveled = true
		if leveled:
			_state.message_log.push("有隊員升級了！")

func recheck() -> void:
	for id in _state.quests.keys():
		_run_quest(id, "recheck")

func entered(map_id: String, pos: Vector2i) -> void:
	for id in _state.quests.keys():
		_run_quest(id, "enter", map_id, pos)

func begin_scene(map_id: String, pos: Vector2i, spec: Dictionary) -> NarrativeScene:
	if not SceneTrigger.should_trigger(spec, _state, _state.is_scene_triggered(map_id, pos)):
		return null
	var run := NarrativeScene.new(_state, map_id, pos, bool(spec.get("once", false)))
	if spec.has("cutscene"):
		run.cutscene = CutsceneCatalog.load(String(spec["cutscene"]))
		if run.cutscene == null:
			return null
	else:
		run.dialogue = DialogueCatalog.load_dialogue(String(spec.get("dialogue", "")))
		if run.dialogue == null:
			return null
	return run
