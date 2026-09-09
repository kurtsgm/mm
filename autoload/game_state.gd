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
var monster_state: Dictionary = {}   # String map_id -> { uid -> {"cell": Vector2i, "state": int} }（持久；大地圖怪位置/狀態）
var quest_resolver: Callable = Callable(QuestCatalog, "load_quest")  # 注入 func(id)->QuestDef（鏡射 SaveSystem.item_resolver）
var _narrative: NarrativeRuntime
var tracked_quest: String = ""     # 追蹤中任務 id（持久；"" = 無）

const STEP_PER_TICK := 5           # 地表中毒外滲：每 N 步 tick 一次
var _poison_steps := 0             # 步數累計（非持久；轉場抵達也算一步）
signal quests_changed
signal quest_event(text: String)   # 接取/推進/完成的瞬間提示文字（給 popup）

func _ready() -> void:
	ItemCatalog.install_resolver()
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
	# 裝備為不可堆疊 ItemInstance（resolver 已於 _ready 安裝）；消耗品仍走可堆疊 id。
	var sword := ItemInstance.new()
	sword.base_id = "short_sword"
	inventory.add_instance(sword)
	var armor := ItemInstance.new()
	armor.base_id = "leather"
	inventory.add_instance(armor)
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

func notify_encounter_defeated(uid: String) -> void:
	mark_encounter_defeated(uid)
	narrative().recheck()

# 踏入某格（走動或轉場抵達）：reach 事件式推進（精確到該圖該格），順帶 recheck 狀態式階段。
func notify_enter(map_id: String, pos: Vector2i) -> void:
	narrative().entered(map_id, pos)
	_poison_steps += 1
	if _poison_steps >= STEP_PER_TICK:
		_poison_steps = 0
		if party != null:
			for line in OverworldAilments.tick_poison(party.members):
				message_log.push(line)

func refresh_collect() -> void:
	narrative().recheck()

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

func set_tracked_quest(id: String) -> void:
	if is_quest_active(id):
		tracked_quest = id
		quests_changed.emit()

# 追蹤中任務若已非進行中 → 改追第一個進行中任務（無則清空）。
func retrack() -> void:
	if is_quest_active(tracked_quest):
		return
	tracked_quest = ""
	for id in quests.keys():
		if is_quest_active(id):
			tracked_quest = id
			return

func _quest_def(id: String):
	if not quest_resolver.is_valid():
		return null
	return quest_resolver.call(id)

# 對單一任務套用一種推進（recheck 狀態式 / talk 對話 / enter 踏格），計算新 state 並 commit。

func _seed_starting_spells() -> void:
	# 骨架起始法術：讓施法系統開局即可操演。正式法術習得屬內容期。
	# Cleric（Marcus）預設昏迷，故另給清醒的 Paladin（Cordelia）heal，野外治療開箱可用。
	for m in party.members:
		match m.char_class:
			"Sorcerer": m.known_spells = ["spark", "flame_wave", "weaken"]
			"Cleric": m.known_spells = ["heal", "revive", "bless"]
			"Paladin": m.known_spells = ["heal"]

# 提供脫離持久狀態的快照：重建世界時，各衍生層使用同一份版本。
func world_snapshot() -> WorldSnapshot:
	return WorldSnapshot.new(opened_objects, cleared_encounters, defeated_encounters, monster_state)

func narrative() -> NarrativeRuntime:
	if _narrative == null:
		_narrative = NarrativeRuntime.new(self)
	return _narrative

func accept_quest(id: String) -> void:
	narrative().accept_quest(id)

func advance_quest(id: String) -> void:
	narrative().advance_quest(id)
