extends Node
# Autoload 單例 "GameState"：全域玩家狀態的家。M3 持有隊伍與訊息列。
# 故意不給 class_name，避免與 autoload 名稱衝突。序列化（存讀檔）屬 M5。

var party: Party
var message_log: MessageLog
var gold: int = 0
var inventory: Inventory

var current_map_id: String = ""
var player_pos: Vector2i = Vector2i.ZERO
var player_facing: int = GridDirection.Dir.NORTH
var cleared_encounters: Dictionary = {}  # String map_id -> Array[Vector2i]
var explored: Dictionary = {}  # String map_id -> Dictionary[Vector2i -> true]（內層當 set）
var opened_objects: Dictionary = {}  # String map_id -> Array[Vector2i]
var flags: Dictionary = {}  # String flag_name -> true（全域故事旗標，當 set）
var triggered_scenes: Dictionary = {}  # String map_id -> Array[Vector2i]（once 場景已觸發）

var quests: Dictionary = {}        # String id -> { "status", "stage" }
var defeated_encounters: Dictionary = {}   # uid -> true（持久；擊敗的遇抵實例）
var quest_resolver: Callable = Callable()  # 注入 func(id)->QuestDef（鏡射 SaveSystem.item_resolver）
signal quests_changed

func _ready() -> void:
	if party == null:
		party = Party.create_default()
		_seed_starting_spells()
	if message_log == null:
		message_log = MessageLog.new()
	if inventory == null:
		inventory = Inventory.new()
		_seed_starting_items()

func mark_encounter_cleared(map_id: String, pos: Vector2i) -> void:
	var list: Array = cleared_encounters.get(map_id, [])
	if not list.has(pos):
		list.append(pos)
	cleared_encounters[map_id] = list

func cleared_for(map_id: String) -> Array:
	return cleared_encounters.get(map_id, [])

func mark_object_opened(map_id: String, pos: Vector2i) -> void:
	var list: Array = opened_objects.get(map_id, [])
	if not list.has(pos):
		list.append(pos)
	opened_objects[map_id] = list

func is_object_opened(map_id: String, pos: Vector2i) -> bool:
	return opened_objects.get(map_id, []).has(pos)

func opened_for(map_id: String) -> Array:
	return opened_objects.get(map_id, [])

func set_flag(name: String) -> void:
	flags[name] = true

func clear_flag(name: String) -> void:
	flags.erase(name)

func has_flag(name: String) -> bool:
	return flags.has(name)

func mark_scene_triggered(map_id: String, pos: Vector2i) -> void:
	var list: Array = triggered_scenes.get(map_id, [])
	if not list.has(pos):
		list.append(pos)
	triggered_scenes[map_id] = list

func is_scene_triggered(map_id: String, pos: Vector2i) -> bool:
	return triggered_scenes.get(map_id, []).has(pos)

func triggered_for(map_id: String) -> Array:
	return triggered_scenes.get(map_id, [])

func mark_explored(map_id: String, pos: Vector2i, w: int, h: int) -> void:
	var seen: Dictionary = explored.get(map_id, {})
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := Vector2i(pos.x + dx, pos.y + dy)
			if c.x < 0 or c.x >= w or c.y < 0 or c.y >= h:
				continue
			seen[c] = true
	explored[map_id] = seen

func is_explored(map_id: String, pos: Vector2i) -> bool:
	return explored.get(map_id, {}).has(pos)

func explored_for(map_id: String) -> Dictionary:
	return explored.get(map_id, {})

func _seed_starting_items() -> void:
	# 骨架起始道具：讓背包/裝備系統開局即可操演。正式起始裝備屬內容期。
	inventory.add("short_sword", 1)
	inventory.add("leather", 1)
	inventory.add("potion", 2)

# --- 任務 ---

# 給 QuestSystem/QuestProgress 的 duck-typed 查詢（狀態式目標判定）。is_explored 已定義於上。
func item_count(item_id: String) -> int:
	return inventory.count_of(item_id) if inventory != null else 0

func is_defeated(uid: String) -> bool:
	return defeated_encounters.has(uid)

func mark_encounter_defeated(uid: String) -> void:
	if uid != "":
		defeated_encounters[uid] = true

func accept_quest(id: String) -> void:
	if quests.has(id):
		return  # 已接/已完成，冪等
	var def = _quest_def(id)
	if def == null:
		return
	quests[id] = QuestSystem.initial_state()
	message_log.push(QuestProgress.accepted_message(def))
	quests_changed.emit()
	_run_quest(id, "recheck")   # 接取追認：已完成的階段（殺過/撿過/到過）立即跳過、不卡死

func advance_quest(id: String) -> void:
	_run_quest(id, "talk")

# 戰鬥勝利時呼叫：記下該遇抵 uid 為已擊敗，再重新評估所有任務。
func notify_encounter_defeated(uid: String) -> void:
	mark_encounter_defeated(uid)
	for id in quests.keys():
		_run_quest(id, "recheck")

# 踏入某格（走動或轉場抵達）：reach 事件式推進（精確到該圖該格），順帶 recheck 狀態式階段。
func notify_enter(map_id: String, pos: Vector2i) -> void:
	for id in quests.keys():
		_run_quest(id, "enter", map_id, pos)

func refresh_collect() -> void:
	for id in quests.keys():
		_run_quest(id, "recheck")

func is_quest_active(id: String) -> bool:
	return quests.has(id) and String(quests[id].get("status", "")) == "active"

func is_quest_done(id: String) -> bool:
	return quests.has(id) and String(quests[id].get("status", "")) == "done"

func is_quest_inactive(id: String) -> bool:
	return not quests.has(id)

func quest_stage(id: String) -> int:
	if is_quest_active(id):
		return int(quests[id]["stage"])
	return -1

func _quest_def(id: String):
	if not quest_resolver.is_valid():
		return null
	return quest_resolver.call(id)

# 對單一任務套用一種推進（recheck 狀態式 / talk 對話 / enter 踏格），計算新 state 並 commit。
func _run_quest(id: String, kind: String, a = null, b = null) -> void:
	if not is_quest_active(id):
		return
	var def = _quest_def(id)
	if def == null:
		return
	var before: Dictionary = quests[id]
	var after: Dictionary
	match kind:
		"talk":
			after = QuestSystem.advance_talk(def, before, self)
		"enter":
			after = QuestSystem.advance_reach(def, before, String(a), b, self)
		_:  # "recheck"
			after = QuestSystem.catch_up(def, before, self)
	_commit_quest(id, def, before, after)

func _commit_quest(id: String, def, before: Dictionary, after: Dictionary) -> void:
	var changed: bool = after["status"] != before["status"] or after["stage"] != before["stage"]
	if not changed:
		return
	quests[id] = after
	if String(after["status"]) == "done":
		_grant_quest_rewards(def)
		message_log.push(QuestProgress.completed_message(def))
	else:
		message_log.push("任務更新：" + QuestProgress.stage_line(def, after, self))
	quests_changed.emit()

func _grant_quest_rewards(def) -> void:
	var g := int(def.rewards.get("gold", 0))
	if g > 0:
		gold += g
	for it in def.rewards.get("items", []):
		inventory.add(String(it), 1)
	var xp := int(def.rewards.get("xp", 0))
	if xp > 0:
		var leveled := false
		for m in party.members:
			if m.is_conscious() and Leveling.grant_xp(m, xp) > 0:
				leveled = true
		if leveled:
			message_log.push("有隊員升級了！")

func _seed_starting_spells() -> void:
	# 骨架起始法術：讓施法系統開局即可操演。正式法術習得屬內容期。
	# Cleric（Marcus）預設昏迷，故另給清醒的 Paladin（Cordelia）heal，野外治療開箱可用。
	for m in party.members:
		match m.char_class:
			"Sorcerer": m.known_spells = ["spark", "flame_wave", "weaken"]
			"Cleric": m.known_spells = ["heal", "revive", "bless"]
			"Paladin": m.known_spells = ["heal"]
