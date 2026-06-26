# 任務鏈系統 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立資料驅動的多階段線性任務鏈系統，支援 talk/kill/collect/reach 四種目標、對話接取/回報、任務日誌面板與訊息列 toast，並進存檔。

**Architecture:** 核心邏輯放 `engine/quest/` 純模組（`QuestDef`/`QuestSystem`/`QuestProgress`，無 Godot 依賴、TDD）；任務狀態存 `GameState.quests`（鏡射 `flags`），任務定義透過注入 `GameState.quest_resolver: Callable`（鏡射 `SaveSystem.item_resolver`）取得；對話系統擴充 quest ops/require；`questgiver` 地圖 entity 重用 `DialogueOverlay`；`QuestLog` CanvasLayer（`J` 鍵）；事件由 `main.gd` 在既有鉤子（戰鬥勝利、進格、開寶箱、對話）餵入。

**Tech Stack:** Godot 4.7 (engine 標 4.2，前向相容)、GDScript、GUT 測試框架、JSON 內容檔。

## Global Constraints

- **不需向後相容**：pre-release 期，不寫相容/回退協商碼；要改格式直接改、一併更新呼叫端與測試資料。
- **UI 版面一律依視窗比例（anchor 比例），不寫死像素**；字級/間距可固定。
- **溝通語言**：對使用者的訊息列文字、UI 標籤一律繁體中文。
- **新增 `class_name` 腳本後，先跑一次 import 再跑 GUT**，否則 global class cache（`.godot`，gitignored）未註冊新 class 會崩：`godot --headless --path . --import`（或 `godot --editor --quit --path .`）。
- **三層分層**：`engine/` 純邏輯（無 Godot 節點/檔案 IO）、`content/` 資料、`presentation/` Godot 節點；`autoload/` 為 glue。`GameState` 保持 catalog-free（用注入的 resolver）。
- **測試指令**（godot 可能不在 PATH，需要時前置 `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`）：
  - 全套：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
  - 單檔：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/<路徑>/test_x.gd -gexit`
- **怪物型別 id**：`goblin`、`ogre`（Task 6 新增 `MonsterDef.id`）。道具 id：`short_sword`/`leather`/`lucky_charm`/`potion`/`ether`/`revive`。遭遇群組 id：`g`=3 隻 goblin、`o`=1 隻 ogre。

---

## 檔案結構總覽

**新增**
- `engine/quest/quest_def.gd`（`class_name QuestDef`）— 任務定義 parse/驗證
- `engine/quest/quest_system.gd`（`class_name QuestSystem`）— 純階段推進邏輯
- `engine/quest/quest_progress.gd`（`class_name QuestProgress`）— 日誌/toast 文字
- `presentation/world/quest_catalog.gd`（`class_name QuestCatalog`）— 載 `content/quests/<id>.json`
- `presentation/ui/quest_log.gd`（`class_name QuestLog`）— `J` 鍵任務日誌面板
- `content/quests/goblin_menace.json` — demo 任務
- `content/dialogues/qg_oak_guard.json` — demo 任務給予/回報對話
- 對應測試檔（見各 Task）

**修改**
- `engine/dialogue/dialogue_condition.gd` — 加 quest_* require
- `engine/dialogue/dialogue_effects.gd` — 加 accept_quest/advance_quest op
- `resources/monster_def.gd` + `content/monsters/goblin.tres` + `content/monsters/ogre.tres` — 加 `id`
- `engine/combat/monster.gd` — 加 `monster_id`，from_def 帶入
- `engine/map/map_importer.gd` + `resources/map_data.gd` — 加 questgiver entity / quest_givers
- `autoload/game_state.gd` — quests 狀態 + 編排方法 + quests_changed signal
- `engine/save/save_data.gd` + `engine/save/save_serializer.gd` + `autoload/save_system.gd` — quests 序列化（VERSION 6）
- `presentation/world/main.gd` — 接線（resolver/QuestLog/J/notify_*）
- `content/maps/town_oak.json` + `content/maps/wild_ne.json` — demo 內容
- `tests/engine/save/test_save_serializer*.gd` 三檔 — VERSION 斷言 5→6

---

## Task 1: QuestDef（任務定義 parse/驗證）

**Files:**
- Create: `engine/quest/quest_def.gd`
- Test: `tests/engine/quest/test_quest_def.gd`

**Interfaces:**
- Produces:
  - `class_name QuestDef extends RefCounted`
  - `var id: String`、`var title: String`、`var stages: Array`、`var rewards: Dictionary`
  - `static func parse(raw: Dictionary) -> QuestDef`（畸形→null）
  - `func stage_count() -> int`、`func stage(i: int) -> Dictionary`
  - stage 正規化後形狀：reach=`{type,map:String,pos:Vector2i,desc}`、kill=`{type,monster:String,count:int,desc}`、collect=`{type,item:String,count:int,desc}`、talk=`{type,desc}`

- [ ] **Step 1: 寫失敗測試**

建立 `tests/engine/quest/test_quest_def.gd`：

```gdscript
extends GutTest

func _raw() -> Dictionary:
	return {
		"id": "q1", "title": "測試任務",
		"stages": [
			{"type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "前往"},
			{"type": "kill", "monster": "goblin", "count": 3, "desc": "擊敗哥布林"},
			{"type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得信物"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 100, "items": ["potion"]},
	}

func test_parse_valid():
	var d := QuestDef.parse(_raw())
	assert_not_null(d)
	assert_eq(d.id, "q1")
	assert_eq(d.title, "測試任務")
	assert_eq(d.stage_count(), 4)
	assert_eq(d.rewards["gold"], 100)

func test_reach_pos_normalized_to_vector2i():
	var d := QuestDef.parse(_raw())
	assert_eq(d.stage(0)["pos"], Vector2i(3, 3))

func test_kill_fields():
	var d := QuestDef.parse(_raw())
	assert_eq(d.stage(1)["monster"], "goblin")
	assert_eq(d.stage(1)["count"], 3)

func test_empty_stages_rejected():
	var r := _raw(); r["stages"] = []
	assert_null(QuestDef.parse(r))

func test_unknown_stage_type_rejected():
	var r := _raw(); r["stages"] = [{"type": "wat", "desc": "x"}]
	assert_null(QuestDef.parse(r))

func test_kill_missing_count_rejected():
	var r := _raw(); r["stages"] = [{"type": "kill", "monster": "goblin", "desc": "x"}]
	assert_null(QuestDef.parse(r))

func test_reach_bad_pos_rejected():
	var r := _raw(); r["stages"] = [{"type": "reach", "map": "m", "pos": [1], "desc": "x"}]
	assert_null(QuestDef.parse(r))

func test_non_dict_rejected():
	assert_null(QuestDef.parse({}))

func test_rewards_default_empty():
	var r := _raw(); r.erase("rewards")
	var d := QuestDef.parse(r)
	assert_eq(d.rewards.get("gold", 0), 0)
	assert_eq(d.rewards.get("items", []), [])
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/quest/test_quest_def.gd -gexit`
Expected: FAIL（`QuestDef` 未定義 / 找不到 class）

- [ ] **Step 3: 寫實作**

建立 `engine/quest/quest_def.gd`：

```gdscript
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
			var pos := _parse_pos(rs["pos"])
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
```

- [ ] **Step 4: import + 跑測試確認通過**

Run: `godot --headless --path . --import`
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/quest/test_quest_def.gd -gexit`
Expected: PASS（10 測試綠）

- [ ] **Step 5: Commit**

```bash
git add engine/quest/quest_def.gd tests/engine/quest/test_quest_def.gd
git commit -m "feat(quest): QuestDef 任務定義 parse/驗證（四型階段正規化）"
```

---

## Task 2: QuestSystem（純階段推進邏輯）

**Files:**
- Create: `engine/quest/quest_system.gd`
- Test: `tests/engine/quest/test_quest_system.gd`

**Interfaces:**
- Consumes: `QuestDef`（`stage(i)`、`stage_count()`）
- Produces:
  - `class_name QuestSystem extends Object`
  - `static func initial_state() -> Dictionary` → `{"status":"active","stage":0,"count":0}`
  - `static func notify_kill(def, state, monster_id: String) -> Dictionary`
  - `static func notify_enter(def, state, map_id: String, pos: Vector2i) -> Dictionary`
  - `static func notify_advance(def, state) -> Dictionary`
  - `static func check_collect(def, state, have_count: Callable) -> Dictionary`（have_count.call(item_id)->int）
  - `static func is_complete(state) -> bool`
  - **不變式**：所有函式**回傳新 dict、不可變更輸入 state**（呼叫端靠比對 stage/count/status 欄位判斷是否變化）

- [ ] **Step 1: 寫失敗測試**

建立 `tests/engine/quest/test_quest_system.gd`：

```gdscript
extends GutTest

func _def() -> QuestDef:
	return QuestDef.parse({
		"id": "q", "title": "T",
		"stages": [
			{"type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "前往"},
			{"type": "kill", "monster": "goblin", "count": 3, "desc": "擊敗"},
			{"type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 10, "items": []},
	})

func _inv(id := "", n := 0) -> Inventory:
	var inv := Inventory.new()
	if id != "":
		inv.add(id, n)
	return inv

func test_initial_state():
	var s := QuestSystem.initial_state()
	assert_eq(s, {"status": "active", "stage": 0, "count": 0})

func test_reach_advances_on_match():
	var s := QuestSystem.notify_enter(_def(), QuestSystem.initial_state(), "wild_ne", Vector2i(3, 3))
	assert_eq(s["stage"], 1)
	assert_eq(s["count"], 0)

func test_reach_no_advance_on_wrong_cell():
	var s := QuestSystem.notify_enter(_def(), QuestSystem.initial_state(), "wild_ne", Vector2i(0, 0))
	assert_eq(s["stage"], 0)

func test_kill_counts_then_advances():
	var st := {"status": "active", "stage": 1, "count": 0}
	st = QuestSystem.notify_kill(_def(), st, "goblin")
	assert_eq(st["count"], 1)
	st = QuestSystem.notify_kill(_def(), st, "goblin")
	st = QuestSystem.notify_kill(_def(), st, "goblin")
	assert_eq(st["stage"], 2)
	assert_eq(st["count"], 0)

func test_kill_wrong_monster_ignored():
	var st := {"status": "active", "stage": 1, "count": 0}
	st = QuestSystem.notify_kill(_def(), st, "ogre")
	assert_eq(st["count"], 0)

func test_kill_on_non_kill_stage_ignored():
	var st := QuestSystem.notify_kill(_def(), QuestSystem.initial_state(), "goblin")
	assert_eq(st["stage"], 0)
	assert_eq(st["count"], 0)

func test_collect_advances_when_have_enough():
	var st := {"status": "active", "stage": 2, "count": 0}
	st = QuestSystem.check_collect(_def(), st, Callable(_inv("lucky_charm", 1), "count_of"))
	assert_eq(st["stage"], 3)

func test_collect_no_advance_when_short():
	var st := {"status": "active", "stage": 2, "count": 0}
	st = QuestSystem.check_collect(_def(), st, Callable(_inv(), "count_of"))
	assert_eq(st["stage"], 2)

func test_talk_advances_and_completes_last_stage():
	var st := {"status": "active", "stage": 3, "count": 0}
	st = QuestSystem.notify_advance(_def(), st)
	assert_true(QuestSystem.is_complete(st))

func test_input_state_not_mutated():
	var before := QuestSystem.initial_state()
	QuestSystem.notify_enter(_def(), before, "wild_ne", Vector2i(3, 3))
	assert_eq(before["stage"], 0)  # 原 state 未被改動

func test_done_state_ignores_events():
	var st := {"status": "done", "stage": 4, "count": 0}
	st = QuestSystem.notify_advance(_def(), st)
	assert_eq(st["stage"], 4)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/quest/test_quest_system.gd -gexit`
Expected: FAIL（`QuestSystem` 未定義）

- [ ] **Step 3: 寫實作**

建立 `engine/quest/quest_system.gd`：

```gdscript
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
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/quest/test_quest_system.gd -gexit`
Expected: PASS（11 測試綠）

- [ ] **Step 5: Commit**

```bash
git add engine/quest/quest_system.gd tests/engine/quest/test_quest_system.gd
git commit -m "feat(quest): QuestSystem 純階段推進（kill/reach/collect/talk + 完成判定）"
```

---

## Task 3: QuestProgress（日誌/toast 文字）

**Files:**
- Create: `engine/quest/quest_progress.gd`
- Test: `tests/engine/quest/test_quest_progress.gd`

**Interfaces:**
- Consumes: `QuestDef`、`QuestSystem` state 形狀
- Produces:
  - `class_name QuestProgress extends Object`
  - `static func stage_line(def, state, have_count: Callable) -> String`
  - `static func accepted_message(def) -> String`
  - `static func completed_message(def) -> String`

- [ ] **Step 1: 寫失敗測試**

建立 `tests/engine/quest/test_quest_progress.gd`：

```gdscript
extends GutTest

func _def() -> QuestDef:
	return QuestDef.parse({
		"id": "q", "title": "哥布林的威脅",
		"stages": [
			{"type": "kill", "monster": "goblin", "count": 3, "desc": "擊敗哥布林"},
			{"type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得信物"},
			{"type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "前往瞭望點"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 100, "items": ["potion"]},
	})

func _inv(id := "", n := 0) -> Inventory:
	var inv := Inventory.new()
	if id != "":
		inv.add(id, n)
	return inv

func test_kill_line_shows_count():
	var st := {"status": "active", "stage": 0, "count": 2}
	assert_eq(QuestProgress.stage_line(_def(), st, Callable(_inv(), "count_of")), "擊敗哥布林 2/3")

func test_collect_line_shows_have():
	var st := {"status": "active", "stage": 1, "count": 0}
	assert_eq(QuestProgress.stage_line(_def(), st, Callable(_inv("lucky_charm", 1), "count_of")), "取得信物 1/1")

func test_reach_line_is_desc_only():
	var st := {"status": "active", "stage": 2, "count": 0}
	assert_eq(QuestProgress.stage_line(_def(), st, Callable(_inv(), "count_of")), "前往瞭望點")

func test_done_line():
	var st := {"status": "done", "stage": 4, "count": 0}
	assert_eq(QuestProgress.stage_line(_def(), st, Callable(_inv(), "count_of")), "已完成")

func test_accepted_message():
	assert_eq(QuestProgress.accepted_message(_def()), "接下任務：哥布林的威脅")

func test_completed_message_lists_rewards():
	assert_eq(QuestProgress.completed_message(_def()), "任務完成：哥布林的威脅，獎勵：100 金幣、potion")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/quest/test_quest_progress.gd -gexit`
Expected: FAIL（`QuestProgress` 未定義）

- [ ] **Step 3: 寫實作**

建立 `engine/quest/quest_progress.gd`：

```gdscript
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
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/quest/test_quest_progress.gd -gexit`
Expected: PASS（6 測試綠）

- [ ] **Step 5: Commit**

```bash
git add engine/quest/quest_progress.gd tests/engine/quest/test_quest_progress.gd
git commit -m "feat(quest): QuestProgress 進度/接取/完成文字"
```

---

## Task 4: DialogueCondition 加 quest_* require

**Files:**
- Modify: `engine/dialogue/dialogue_condition.gd`
- Modify: `tests/engine/dialogue/test_dialogue_condition.gd`

**Interfaces:**
- Consumes: ctx 須提供 `is_quest_active(id)->bool`、`is_quest_done(id)->bool`、`is_quest_inactive(id)->bool`、`quest_stage(id)->int`
- Produces: require 支援新鍵 `quest_active`/`quest_done`/`quest_inactive`（值=id 字串）、`quest_stage`（值=`{id,eq}`）

- [ ] **Step 1: 寫失敗測試**

在 `tests/engine/dialogue/test_dialogue_condition.gd` 的 `FakeCtx` 內補 quest 方法，並加測試：

先把檔頭 `FakeCtx` 改成：

```gdscript
class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}
	var quests: Dictionary = {}   # id -> {"status","stage"}
	func is_quest_inactive(id) -> bool: return not quests.has(id)
	func is_quest_active(id) -> bool: return quests.has(id) and quests[id]["status"] == "active"
	func is_quest_done(id) -> bool: return quests.has(id) and quests[id]["status"] == "done"
	func quest_stage(id) -> int: return int(quests[id]["stage"]) if is_quest_active(id) else -1
```

在檔尾加測試：

```gdscript
func test_quest_inactive():
	var c := _ctx()
	assert_true(DialogueCondition.passes({"quest_inactive": "q"}, c))
	c.quests["q"] = {"status": "active", "stage": 0}
	assert_false(DialogueCondition.passes({"quest_inactive": "q"}, c))

func test_quest_active_and_done():
	var c := _ctx()
	c.quests["q"] = {"status": "active", "stage": 0}
	assert_true(DialogueCondition.passes({"quest_active": "q"}, c))
	assert_false(DialogueCondition.passes({"quest_done": "q"}, c))
	c.quests["q"] = {"status": "done", "stage": 4}
	assert_true(DialogueCondition.passes({"quest_done": "q"}, c))

func test_quest_stage_eq():
	var c := _ctx()
	c.quests["q"] = {"status": "active", "stage": 3}
	assert_true(DialogueCondition.passes({"quest_stage": {"id": "q", "eq": 3}}, c))
	assert_false(DialogueCondition.passes({"quest_stage": {"id": "q", "eq": 2}}, c))

func test_quest_stage_false_when_done():
	var c := _ctx()
	c.quests["q"] = {"status": "done", "stage": 4}
	assert_false(DialogueCondition.passes({"quest_stage": {"id": "q", "eq": 4}}, c))
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/dialogue/test_dialogue_condition.gd -gexit`
Expected: FAIL（新 require 鍵走 `_` 分支回 false）

- [ ] **Step 3: 寫實作**

在 `engine/dialogue/dialogue_condition.gd` 的 `match key:` 內，於 `"flag":` 之後、`"is":` 之前（或任意位置，但在 `_:` 之前）插入：

```gdscript
			"quest_active":
				if not ctx.is_quest_active(String(require[key])):
					return false
			"quest_done":
				if not ctx.is_quest_done(String(require[key])):
					return false
			"quest_inactive":
				if not ctx.is_quest_inactive(String(require[key])):
					return false
			"quest_stage":
				var spec = require[key]
				if typeof(spec) != TYPE_DICTIONARY:
					return false
				if ctx.quest_stage(String(spec.get("id", ""))) != int(spec.get("eq", -999)):
					return false
```

- [ ] **Step 4: 跑測試確認通過（含全套 dialogue condition 既有測試不退化）**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/dialogue/test_dialogue_condition.gd -gexit`
Expected: PASS（既有 + 4 新測試綠）

- [ ] **Step 5: Commit**

```bash
git add engine/dialogue/dialogue_condition.gd tests/engine/dialogue/test_dialogue_condition.gd
git commit -m "feat(quest): DialogueCondition 加 quest_active/done/inactive/stage require"
```

---

## Task 5: DialogueEffects 加 accept_quest / advance_quest op

**Files:**
- Modify: `engine/dialogue/dialogue_effects.gd`
- Modify: `tests/engine/dialogue/test_dialogue_effects.gd`

**Interfaces:**
- Consumes: ctx 須提供 `accept_quest(id)`、`advance_quest(id)`（由 GameState 自行推訊息/emit；故 op 不另加描述，避免重複 toast）
- Produces: effects op `accept_quest`/`advance_quest`（值含 `quest` 鍵）

- [ ] **Step 1: 寫失敗測試**

在 `tests/engine/dialogue/test_dialogue_effects.gd` 的 `FakeCtx` 內補：

```gdscript
	var accepted: Array = []
	var advanced: Array = []
	func accept_quest(id) -> void: accepted.append(id)
	func advance_quest(id) -> void: advanced.append(id)
```

於檔尾加測試：

```gdscript
func test_accept_quest_op_calls_ctx():
	var c := FakeCtx.new()
	DialogueEffects.apply([{"op": "accept_quest", "quest": "q1"}], c)
	assert_eq(c.accepted, ["q1"])

func test_advance_quest_op_calls_ctx():
	var c := FakeCtx.new()
	DialogueEffects.apply([{"op": "advance_quest", "quest": "q1"}], c)
	assert_eq(c.advanced, ["q1"])

func test_quest_ops_emit_no_description():
	var c := FakeCtx.new()
	var out := DialogueEffects.apply([{"op": "accept_quest", "quest": "q1"}], c)
	assert_eq(out, [])  # toast 由 GameState 負責，避免重複
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/dialogue/test_dialogue_effects.gd -gexit`
Expected: FAIL（accept_quest/advance_quest 走 `_` 分支被跳過）

- [ ] **Step 3: 寫實作**

在 `engine/dialogue/dialogue_effects.gd` 的 `match String(e.get("op", "")):` 內，於 `"clear_flag":` 之後、`_:` 之前插入：

```gdscript
			"accept_quest":
				var aqid := String(e.get("quest", ""))
				if aqid != "":
					ctx.accept_quest(aqid)
			"advance_quest":
				var vqid := String(e.get("quest", ""))
				if vqid != "":
					ctx.advance_quest(vqid)
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/dialogue/test_dialogue_effects.gd -gexit`
Expected: PASS（既有 + 3 新測試綠）

- [ ] **Step 5: Commit**

```bash
git add engine/dialogue/dialogue_effects.gd tests/engine/dialogue/test_dialogue_effects.gd
git commit -m "feat(quest): DialogueEffects 加 accept_quest/advance_quest op"
```

---

## Task 6: MonsterDef.id + Monster.monster_id（kill 目標可辨識怪物型別）

**Files:**
- Modify: `resources/monster_def.gd`（加 `@export var id`）
- Modify: `content/monsters/goblin.tres`、`content/monsters/ogre.tres`（加 `id`）
- Modify: `engine/combat/monster.gd`（加 `var monster_id`，from_def 帶入）
- Test: `tests/engine/combat/test_monster_id.gd`

**Interfaces:**
- Produces: `MonsterDef.id: String`；`Monster.monster_id: String`（`Monster.from_def` 從 `def.id` 帶入）

- [ ] **Step 1: 寫失敗測試**

建立 `tests/engine/combat/test_monster_id.gd`：

```gdscript
extends GutTest

func test_from_def_copies_monster_id():
	var def := MonsterDef.new()
	def.id = "goblin"
	def.hp_max = 5
	var m := Monster.from_def(def)
	assert_eq(m.monster_id, "goblin")

func test_goblin_tres_has_id():
	var def: MonsterDef = load("res://content/monsters/goblin.tres")
	assert_eq(def.id, "goblin")

func test_ogre_tres_has_id():
	var def: MonsterDef = load("res://content/monsters/ogre.tres")
	assert_eq(def.id, "ogre")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/combat/test_monster_id.gd -gexit`
Expected: FAIL（`MonsterDef.id` / `Monster.monster_id` 不存在）

- [ ] **Step 3: 寫實作**

`resources/monster_def.gd`：在 `@export var display_name: String = ""` 上方加：

```gdscript
@export var id: String = ""
```

`engine/combat/monster.gd`：在 `var name: String` 上方加：

```gdscript
var monster_id: String
```

並在 `from_def` 內 `m.name = def.display_name` 上方加：

```gdscript
	m.monster_id = def.id
```

`content/monsters/goblin.tres`：在 `[resource]` 區塊 `script = ExtResource("1_def")` 之後加一行：

```
id = "goblin"
```

`content/monsters/ogre.tres`：同樣在 `script = ExtResource("1_def")` 之後加：

```
id = "ogre"
```

- [ ] **Step 4: import + 跑測試確認通過**

Run: `godot --headless --path . --import`
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/combat/test_monster_id.gd -gexit`
Expected: PASS（3 測試綠）

- [ ] **Step 5: Commit**

```bash
git add resources/monster_def.gd engine/combat/monster.gd content/monsters/goblin.tres content/monsters/ogre.tres tests/engine/combat/test_monster_id.gd
git commit -m "feat(quest): MonsterDef.id + Monster.monster_id（kill 目標辨識怪物型別）"
```

---

## Task 7: questgiver entity → MapData.quest_givers

**Files:**
- Modify: `engine/map/map_importer.gd`
- Modify: `resources/map_data.gd`
- Modify: `tests/engine/map/test_map_importer.gd`（或既有 importer 測試檔；若不同名見 Step 1）
- Test（MapData）: `tests/resources/test_map_data.gd`

**Interfaces:**
- Produces:
  - `MapData.quest_givers: Array`（`[{pos:Vector2i, dialogue:String}]`）+ `has_quest_giver(pos)->bool`、`get_quest_giver(pos)->Dictionary`
  - `MapImporter` 解析 `{type:"questgiver", pos, dialogue}`；缺 dialogue → null

- [ ] **Step 1: 寫失敗測試**

先確認 importer 測試檔位置：`ls tests/engine/map/`（預期含 `test_map_importer.gd`）。在該檔加：

```gdscript
func test_questgiver_entity_parsed():
	var json := '{"grid":["@."],"entities":[{"type":"questgiver","pos":[1,0],"dialogue":"qg_x"}]}'
	var map := MapImporter.parse(json)
	assert_not_null(map)
	assert_true(map.has_quest_giver(Vector2i(1, 0)))
	assert_eq(map.get_quest_giver(Vector2i(1, 0))["dialogue"], "qg_x")

func test_questgiver_missing_dialogue_rejected():
	var json := '{"grid":["@."],"entities":[{"type":"questgiver","pos":[1,0]}]}'
	assert_null(MapImporter.parse(json))
```

在 `tests/resources/test_map_data.gd` 加：

```gdscript
func test_quest_giver_accessors():
	var m := MapData.new()
	m.quest_givers = [{"pos": Vector2i(1, 1), "dialogue": "qg_x"}]
	assert_true(m.has_quest_giver(Vector2i(1, 1)))
	assert_false(m.has_quest_giver(Vector2i(0, 0)))
	assert_eq(m.get_quest_giver(Vector2i(1, 1))["dialogue"], "qg_x")
	assert_eq(m.get_quest_giver(Vector2i(0, 0)), {})
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/map/test_map_importer.gd -gexit`
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/resources/test_map_data.gd -gexit`
Expected: FAIL（quest_givers / has_quest_giver 不存在）

- [ ] **Step 3: 寫實作**

`resources/map_data.gd`：在 `@export var vendors: Array = []` 之後加：

```gdscript
@export var quest_givers: Array = []   # [{ pos:Vector2i, dialogue:String }]
```

並在檔尾（`get_vendor` 之後）加：

```gdscript
func has_quest_giver(pos: Vector2i) -> bool:
	for q in quest_givers:
		if q["pos"] == pos:
			return true
	return false

func get_quest_giver(pos: Vector2i) -> Dictionary:
	for q in quest_givers:
		if q["pos"] == pos:
			return q
	return {}
```

`engine/map/map_importer.gd`：
1. 在 `_parse_entities` 開頭的本地集合宣告區，於 `var vendors := []` 之後加 `var quest_givers := []`。
2. 在 `match` 內 `"vendor":` 分支之後、`_:` 之前加：

```gdscript
			"questgiver":
				if not e.has("dialogue"):
					return null
				quest_givers.append({"pos": pos, "dialogue": String(e["dialogue"])})
```

3. 把回傳 dict 加上 quest_givers：

```gdscript
	return {"encounters": encounters, "links": links, "decorations": decorations, "objects": objects, "scenes": scenes, "vendors": vendors, "quest_givers": quest_givers}
```

4. 在 `parse()` 的指派區（`map.vendors = entities["vendors"]` 之後）加：

```gdscript
	map.quest_givers = entities["quest_givers"]
```

- [ ] **Step 4: import + 跑測試確認通過**

Run: `godot --headless --path . --import`
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/map/test_map_importer.gd -gexit`
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/resources/test_map_data.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add engine/map/map_importer.gd resources/map_data.gd tests/engine/map/test_map_importer.gd tests/resources/test_map_data.gd
git commit -m "feat(quest): questgiver entity → MapData.quest_givers + 存取子"
```

---

## Task 8: GameState 任務狀態 + 編排方法

**Files:**
- Modify: `autoload/game_state.gd`
- Test: `tests/autoload/test_game_state_quests.gd`

**Interfaces:**
- Consumes: `QuestDef`、`QuestSystem`、`QuestProgress`、`Inventory.count_of`
- Produces（GameState）:
  - `var quests: Dictionary`、`var quest_resolver: Callable`、`signal quests_changed`
  - `accept_quest(id)`、`advance_quest(id)`、`notify_kill(monster_id)`、`notify_enter(map_id, pos)`、`refresh_collect()`
  - `is_quest_active(id)`、`is_quest_done(id)`、`is_quest_inactive(id)`、`quest_stage(id)`

- [ ] **Step 1: 寫失敗測試**

建立 `tests/autoload/test_game_state_quests.gd`：

```gdscript
extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

var _def: QuestDef

func _gs() -> Node:
	var gs = GameStateScript.new()
	add_child_autofree(gs)
	gs.quest_resolver = Callable(self, "_resolve")
	return gs

func _resolve(id) -> QuestDef:
	return _def if id == "q" else null

func before_each():
	_def = QuestDef.parse({
		"id": "q", "title": "哥布林的威脅",
		"stages": [
			{"type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "前往"},
			{"type": "kill", "monster": "goblin", "count": 2, "desc": "擊敗"},
			{"type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 100, "items": ["potion"]},
	})

func test_accept_sets_active_stage0():
	var gs = _gs()
	assert_true(gs.is_quest_inactive("q"))
	gs.accept_quest("q")
	assert_true(gs.is_quest_active("q"))
	assert_eq(gs.quest_stage("q"), 0)

func test_accept_idempotent():
	var gs = _gs()
	gs.accept_quest("q")
	gs.accept_quest("q")
	assert_eq(gs.quests.size(), 1)

func test_reach_then_kill_then_collect_then_talk_completes_and_rewards():
	var gs = _gs()
	gs.accept_quest("q")
	gs.notify_enter("wild_ne", Vector2i(3, 3))
	assert_eq(gs.quest_stage("q"), 1)
	gs.notify_kill("goblin")
	gs.notify_kill("goblin")
	assert_eq(gs.quest_stage("q"), 2)
	gs.inventory.add("lucky_charm", 1)
	gs.refresh_collect()
	assert_eq(gs.quest_stage("q"), 3)
	var gold_before: int = gs.gold
	gs.advance_quest("q")
	assert_true(gs.is_quest_done("q"))
	assert_eq(gs.gold, gold_before + 100)
	assert_eq(gs.inventory.count_of("potion"), 3)  # 起始 2 + 獎勵 1

func test_quests_changed_emitted_on_progress():
	var gs = _gs()
	watch_signals(gs)
	gs.accept_quest("q")
	assert_signal_emitted(gs, "quests_changed")

func test_notify_ignores_unknown_active_quest_without_resolver():
	var gs = _gs()
	gs.quest_resolver = Callable()  # 無 resolver
	gs.accept_quest("q")            # 無 def → 不接
	assert_true(gs.is_quest_inactive("q"))
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/autoload/test_game_state_quests.gd -gexit`
Expected: FAIL（quest 方法不存在）

- [ ] **Step 3: 寫實作**

`autoload/game_state.gd`：
1. 在變數宣告區（`var triggered_scenes` 之後）加：

```gdscript
var quests: Dictionary = {}        # String id -> { "status", "stage", "count" }
var quest_resolver: Callable = Callable()  # 注入 func(id)->QuestDef（鏡射 SaveSystem.item_resolver）
signal quests_changed
```

2. 在檔尾（`_seed_starting_spells` 之前）加：

```gdscript
# --- 任務 ---

func accept_quest(id: String) -> void:
	if quests.has(id):
		return  # 已接/已完成，冪等
	var def = _quest_def(id)
	if def == null:
		return
	quests[id] = QuestSystem.initial_state()
	message_log.push(QuestProgress.accepted_message(def))
	quests_changed.emit()

func advance_quest(id: String) -> void:
	_run_quest(id, "advance")

func notify_kill(monster_id: String) -> void:
	for id in quests.keys():
		_run_quest(id, "kill", monster_id)

func notify_enter(map_id: String, pos: Vector2i) -> void:
	for id in quests.keys():
		_run_quest(id, "enter", map_id, pos)

func refresh_collect() -> void:
	for id in quests.keys():
		_run_quest(id, "collect")

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

# 對單一任務套用一種事件，計算新 state 並 commit。
func _run_quest(id: String, kind: String, a = null, b = null) -> void:
	if not is_quest_active(id):
		return
	var def = _quest_def(id)
	if def == null:
		return
	var before: Dictionary = quests[id]
	var after: Dictionary = before
	match kind:
		"advance":
			after = QuestSystem.notify_advance(def, before)
		"kill":
			after = QuestSystem.notify_kill(def, before, String(a))
		"enter":
			after = QuestSystem.notify_enter(def, before, String(a), b)
		"collect":
			after = QuestSystem.check_collect(def, before, Callable(inventory, "count_of"))
	_commit_quest(id, def, before, after)

func _commit_quest(id: String, def, before: Dictionary, after: Dictionary) -> void:
	var changed := after["status"] != before["status"] or after["stage"] != before["stage"] or after["count"] != before["count"]
	if not changed:
		return
	quests[id] = after
	if String(after["status"]) == "done":
		_grant_quest_rewards(def)
		message_log.push(QuestProgress.completed_message(def))
	else:
		message_log.push("任務更新：" + QuestProgress.stage_line(def, after, Callable(inventory, "count_of")))
	quests_changed.emit()

func _grant_quest_rewards(def) -> void:
	var g := int(def.rewards.get("gold", 0))
	if g > 0:
		gold += g
	for it in def.rewards.get("items", []):
		inventory.add(String(it), 1)
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/autoload/test_game_state_quests.gd -gexit`
Expected: PASS（6 測試綠）

- [ ] **Step 5: Commit**

```bash
git add autoload/game_state.gd tests/autoload/test_game_state_quests.gd
git commit -m "feat(quest): GameState 任務狀態 + 編排（accept/advance/notify/發獎/quests_changed）"
```

---

## Task 9: 存檔整合（VERSION 6 + quests，移除舊版接受）

**Files:**
- Modify: `engine/save/save_data.gd`
- Modify: `engine/save/save_serializer.gd`
- Modify: `autoload/save_system.gd`
- Modify: 4 個存檔測試檔（`test_save_serializer.gd`、`test_save_serializer_flags.gd`、`test_save_serializer_spells.gd`、`test_save_serializer_items.gd`）：VERSION 斷言 5→6、舊版載入測試改寫
- Test: `tests/engine/save/test_save_serializer_quests.gd`

**設計決策（使用者 2026-06-26 拍板）**：依「不需向後相容」guideline，**移除舊版接受清單**，`from_dict` 只接受目前 VERSION（6），version != 6 一律回 null。既有「載舊版 vX」測試一併改寫：原本驗「缺新欄→空預設」的，改成在目前版本下驗（version 設 `SaveSerializer.VERSION`，斷言不變）；原本驗「舊版被接受」的，改成驗「舊版被拒（null）」。

**Interfaces:**
- Produces: `SaveData.quests: Dictionary`；序列化 `state.quests`（`{id:{status,stage,count}}`）；`SaveSerializer.VERSION == 6`；`from_dict` 對 version != 6 一律回 null

- [ ] **Step 1: 寫失敗測試**

建立 `tests/engine/save/test_save_serializer_quests.gd`：

```gdscript
extends GutTest

func _data() -> SaveData:
	var d := SaveData.new()
	d.party = Party.new()
	d.inventory = Inventory.new()
	d.quests = {"q": {"status": "active", "stage": 1, "count": 2}}
	return d

func test_quests_round_trip():
	var raw := SaveSerializer.to_dict(_data())
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.quests["q"]["status"], "active")
	assert_eq(back.quests["q"]["stage"], 1)
	assert_eq(back.quests["q"]["count"], 2)

func test_quests_absent_is_empty():
	var raw := SaveSerializer.to_dict(_data())
	raw["state"].erase("quests")
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.quests, {})

func test_version_is_6():
	assert_eq(SaveSerializer.to_dict(_data())["version"], 6)

func test_old_version_rejected():
	var raw := SaveSerializer.to_dict(_data())
	raw["version"] = 5
	assert_null(SaveSerializer.from_dict(raw), "舊版不再接受（只收 v6）")
```

改寫既有 4 檔（移除「舊版被接受」假設）。逐項精確修改：

`tests/engine/save/test_save_serializer.gd`：
- 第 78–79 行 `test_to_dict_version_is_5` → 改名 `test_to_dict_version_is_6`、body 改 `assert_eq(SaveSerializer.to_dict(_sample())["version"], 6)`。
- 第 93–104 行 `test_old_v3_save_gets_empty_explored` → 改名 `test_missing_explored_loads_empty`，把 raw 內 `"version": 3,` 改成 `"version": SaveSerializer.VERSION,`，其餘斷言（`assert_not_null` + `back.explored.size()==0`）不變。
- 第 121–126 行 `test_opened_objects_absent_is_empty` → 把 `var raw := {"version": 4, "state": {"player_pos": [0, 0]}}` 改成 `var raw := {"version": SaveSerializer.VERSION, "state": {"player_pos": [0, 0]}}`，其餘不變。
- `test_from_dict_rejects_version_mismatch`（v999）保留不動。

`tests/engine/save/test_save_serializer_flags.gd`：
- 第 11–12 行 `test_version_is_5` → 改名 `test_version_is_6`、body 改 `assert_eq(SaveSerializer.to_dict(_data())["version"], 6)`。
- 第 20–28 行 `test_old_v4_without_new_fields_loads_empty` → 改名 `test_missing_flags_and_scenes_load_empty`，刪除 `raw["version"] = 4` 那一行（raw 由 to_dict 產生已是 6），其餘（erase flags/triggered_scenes + 斷言空）不變。

`tests/engine/save/test_save_serializer_spells.gd`：
- 第 15–16 行 `test_version_is_5` → 改名 `test_version_is_6`、body 改 `assert_eq(SaveSerializer.to_dict(_sample())["version"], 6)`。
- 第 18–30 行 `test_version_2_save_gets_empty_known_spells` → 改名 `test_missing_known_spells_loads_empty`，把 raw 內 `"version": 2,` 改成 `"version": SaveSerializer.VERSION,`，其餘斷言不變。
- 第 32–42 行 `test_version_1_save_still_accepted` → 改名 `test_old_version_1_rejected`，保留 raw（含 `"version": 1`），body 改 `assert_null(SaveSerializer.from_dict(raw), "舊版 v1 不再接受")`。

`tests/engine/save/test_save_serializer_items.gd`：
- 第 50–65 行 `test_accepts_version_1_save_with_empty_items` → 改名 `test_missing_items_fields_load_empty`，把 raw 內 `"version": 1,` 改成 `"version": SaveSerializer.VERSION,`，其餘斷言（gold 50 / inventory 空 / equipment total_attack 0）不變。

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/save/test_save_serializer_quests.gd -gexit`
Expected: FAIL（`SaveData.quests` 不存在 / version 仍 5）

- [ ] **Step 3: 寫實作**

`engine/save/save_data.gd`：在 `var triggered_scenes` 之後加：

```gdscript
var quests: Dictionary = {}  # String id -> { status, stage, count }
```

`engine/save/save_serializer.gd`：
1. `const VERSION := 5` → `const VERSION := 6`
2. `to_dict` 的 `"state"` dict 內，`"triggered_scenes"` 之後加：

```gdscript
			"quests": _quests_to_dict(data.quests),
```

3. `from_dict` 的版本守門整行換成（移除舊版接受清單）：

```gdscript
	if v != VERSION:   # 不需向後相容：只接受目前版本，舊檔不再載入
		return null
```

（原行為 `if v != VERSION and v != 1 ... : return null` 兩行，換成上面這兩行。）

4. `from_dict` 的指派區，`data.triggered_scenes = ...` 之後加：

```gdscript
	data.quests = _quests_from_dict(s.get("quests", {}))
```

5. 在檔尾（`_flags_from_array` 之後）加：

```gdscript
static func _quests_to_dict(quests: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id in quests:
		var q: Dictionary = quests[id]
		out[String(id)] = {
			"status": String(q.get("status", "active")),
			"stage": int(q.get("stage", 0)),
			"count": int(q.get("count", 0)),
		}
	return out

static func _quests_from_dict(raw) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for id in raw:
		var q = raw[id]
		if typeof(q) != TYPE_DICTIONARY:
			continue
		out[String(id)] = {
			"status": String(q.get("status", "active")),
			"stage": int(q.get("stage", 0)),
			"count": int(q.get("count", 0)),
		}
	return out
```

`autoload/save_system.gd`：
- `capture_from` 內 `data.triggered_scenes = gs.triggered_scenes` 之後加：`data.quests = gs.quests`
- `apply_to` 內 `gs.triggered_scenes = data.triggered_scenes` 之後加：`gs.quests = data.quests`

- [ ] **Step 4: 跑全套存檔測試確認通過**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine/save -ginclude_subdirs -gexit`
Expected: PASS（含新 quests 檔 + 三檔 version 6 + 既有不退化）

- [ ] **Step 5: Commit**

```bash
git add engine/save/save_data.gd engine/save/save_serializer.gd autoload/save_system.gd tests/engine/save/
git commit -m "feat(quest): 存檔加入 quests（VERSION 6，移除舊版接受）+ SaveSystem capture/apply"
```

---

## Task 10: QuestCatalog（載 content/quests/<id>.json）

**Files:**
- Create: `presentation/world/quest_catalog.gd`
- Test: `tests/presentation/test_quest_catalog.gd`
- Create（測試夾具用，亦為 Task 12 demo）: 暫不需要；測試用 inline 寫入 user:// 不便，改測「缺檔回 null」+ 真檔在 Task 12 驗證。

**Interfaces:**
- Consumes: `QuestDef.parse`
- Produces: `class_name QuestCatalog`；`static func load_quest(id: String) -> QuestDef`（缺檔/畸形→null）

- [ ] **Step 1: 寫失敗測試**

建立 `tests/presentation/test_quest_catalog.gd`：

```gdscript
extends GutTest

func test_missing_quest_returns_null():
	assert_null(QuestCatalog.load_quest("___nope___"))
```

（真任務檔的成功載入於 Task 12 內容驗證測試覆蓋，避免本 Task 依賴尚未建立的內容檔。）

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_quest_catalog.gd -gexit`
Expected: FAIL（`QuestCatalog` 未定義）

- [ ] **Step 3: 寫實作**

建立 `presentation/world/quest_catalog.gd`：

```gdscript
class_name QuestCatalog
extends Object
# 任務 id → 載 content/quests/<id>.json → QuestDef（鏡射 DialogueCatalog）。
# 檔缺 / JSON 畸形 / 定義違規 → null。

const QUESTS_DIR := "res://content/quests"

static func load_quest(id: String) -> QuestDef:
	var path := "%s/%s.json" % [QUESTS_DIR, id]
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	return QuestDef.parse(raw)
```

- [ ] **Step 4: import + 跑測試確認通過**

Run: `godot --headless --path . --import`
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_quest_catalog.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add presentation/world/quest_catalog.gd tests/presentation/test_quest_catalog.gd
git commit -m "feat(quest): QuestCatalog 載 content/quests/<id>.json"
```

---

## Task 11: QuestLog UI（J 鍵任務日誌面板）

**Files:**
- Create: `presentation/ui/quest_log.gd`
- Test: `tests/presentation/test_quest_log.gd`（只測純 `summary_lines`，`_draw`/節點渲染不測，沿用 HUD 慣例）

**Interfaces:**
- Consumes: `QuestProgress.stage_line`
- Produces:
  - `class_name QuestLog extends CanvasLayer`
  - `is_open()/open()/close()`、`signal closed`、`func refresh()`
  - `static func summary_lines(quests: Dictionary, resolver: Callable, have_count: Callable) -> Array`（純、可測）

- [ ] **Step 1: 寫失敗測試**

建立 `tests/presentation/test_quest_log.gd`：

```gdscript
extends GutTest

var _def: QuestDef

func _resolve(id) -> QuestDef:
	return _def if id == "q" else null

func before_each():
	_def = QuestDef.parse({
		"id": "q", "title": "哥布林的威脅",
		"stages": [
			{"type": "kill", "monster": "goblin", "count": 3, "desc": "擊敗哥布林"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 10, "items": []},
	})

func test_summary_lists_active_with_progress():
	var quests := {"q": {"status": "active", "stage": 0, "count": 1}}
	var lines := QuestLog.summary_lines(quests, Callable(self, "_resolve"), Callable(Inventory.new(), "count_of"))
	var joined := "\n".join(lines)
	assert_true(joined.contains("哥布林的威脅"))
	assert_true(joined.contains("擊敗哥布林 1/3"))

func test_summary_lists_done():
	var quests := {"q": {"status": "done", "stage": 2, "count": 0}}
	var lines := QuestLog.summary_lines(quests, Callable(self, "_resolve"), Callable(Inventory.new(), "count_of"))
	assert_true("\n".join(lines).contains("哥布林的威脅"))

func test_summary_empty_when_no_quests():
	var lines := QuestLog.summary_lines({}, Callable(self, "_resolve"), Callable(Inventory.new(), "count_of"))
	var joined := "\n".join(lines)
	assert_true(joined.contains("進行中"))
	assert_true(joined.contains("（無）"))
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_quest_log.gd -gexit`
Expected: FAIL（`QuestLog` 未定義）

- [ ] **Step 3: 寫實作**

建立 `presentation/ui/quest_log.gd`（版面比例式：面板用 anchor 置中、約占畫面 60% 寬 70% 高）：

```gdscript
class_name QuestLog
extends CanvasLayer
# J 鍵開關的任務日誌面板。進行中顯示標題＋當前階段進度；已完成另列。
# 版面用 anchor 比例（解析度無關）。文字邏輯走純 summary_lines（可測）。

signal closed

var _panel: Panel
var _label: Label

func is_open() -> bool:
	return visible

func open() -> void:
	visible = true
	set_process_unhandled_input(true)
	refresh()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	closed.emit()

func _ready() -> void:
	layer = 10
	visible = false
	_panel = Panel.new()
	_panel.anchor_left = 0.2
	_panel.anchor_right = 0.8
	_panel.anchor_top = 0.15
	_panel.anchor_bottom = 0.85
	add_child(_panel)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 16
	_label.offset_top = 12
	_label.offset_right = -16
	_label.offset_bottom = -12
	_label.add_theme_font_size_override("font_size", 18)
	_panel.add_child(_label)
	set_process_unhandled_input(false)

func refresh() -> void:
	_label.text = "\n".join(summary_lines(
		GameState.quests, GameState.quest_resolver, Callable(GameState.inventory, "count_of")))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_J:
		close()

static func summary_lines(quests: Dictionary, resolver: Callable, have_count: Callable) -> Array:
	var active: Array[String] = []
	var done: Array[String] = []
	for id in quests:
		var def = resolver.call(id) if resolver.is_valid() else null
		if def == null:
			continue
		var state: Dictionary = quests[id]
		if String(state.get("status", "")) == "done":
			done.append("✓ %s" % def.title)
		else:
			active.append("● %s — %s" % [def.title, QuestProgress.stage_line(def, state, have_count)])
	var lines: Array[String] = ["== 任務日誌 ==  [J/Esc] 關"]
	lines.append("-- 進行中 --")
	if active.is_empty():
		lines.append("（無）")
	else:
		lines.append_array(active)
	lines.append("-- 已完成 --")
	if done.is_empty():
		lines.append("（無）")
	else:
		lines.append_array(done)
	return lines
```

- [ ] **Step 4: import + 跑測試確認通過**

Run: `godot --headless --path . --import`
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_quest_log.gd -gexit`
Expected: PASS（3 測試綠）

- [ ] **Step 5: Commit**

```bash
git add presentation/ui/quest_log.gd tests/presentation/test_quest_log.gd
git commit -m "feat(quest): QuestLog 任務日誌面板（J 鍵，比例式，summary_lines 可測）"
```

---

## Task 12: Demo 內容「哥布林的威脅」

**Files:**
- Create: `content/quests/goblin_menace.json`
- Create: `content/dialogues/qg_oak_guard.json`
- Modify: `content/maps/town_oak.json`（加 questgiver）
- Modify: `content/maps/wild_ne.json`（加 goblin encounter + lucky_charm 寶箱）
- Test: `tests/content/test_quest_content.gd`

**設計備忘（階段順序刻意 kill→collect→reach→talk）**：kill 為 stage 0，玩家進 `wild_ne` 即可開打、擊殺一定計入，避免「reach 未完成前打怪、一次性遭遇白費」的順序陷阱；collect 採「目前持有≥N」故即使提早開箱也能在進到 collect 階段時自動完成；reach 末段瞭望格、talk 回鎮回報。

**Interfaces:**
- Consumes: `QuestCatalog.load_quest`、`DialogueCatalog.load_dialogue`、`MapImporter.parse`

- [ ] **Step 1: 寫失敗測試**

建立 `tests/content/test_quest_content.gd`：

```gdscript
extends GutTest

func test_goblin_menace_loads():
	var d := QuestCatalog.load_quest("goblin_menace")
	assert_not_null(d)
	assert_eq(d.stage_count(), 4)
	assert_eq(d.stage(0)["type"], "kill")
	assert_eq(d.stage(1)["type"], "collect")
	assert_eq(d.stage(2)["type"], "reach")
	assert_eq(d.stage(3)["type"], "talk")

func test_qg_oak_guard_dialogue_loads():
	assert_not_null(DialogueCatalog.load_dialogue("qg_oak_guard"))

func test_town_oak_has_questgiver():
	var map := MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/town_oak.json"))
	assert_not_null(map)
	assert_true(map.has_quest_giver(Vector2i(2, 1)))

func test_wild_ne_has_goblin_and_chest():
	var map := MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/wild_ne.json"))
	assert_not_null(map)
	assert_eq(map.get_encounter(Vector2i(1, 1)), "g")
	assert_true(map.has_object(Vector2i(3, 1)))
	assert_eq(map.get_object(Vector2i(3, 1))["items"], ["lucky_charm"])
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/content/test_quest_content.gd -gexit`
Expected: FAIL（內容檔尚未建立 / town_oak 無 questgiver）

- [ ] **Step 3: 建立內容**

建立 `content/quests/goblin_menace.json`：

```json
{
  "id": "goblin_menace",
  "title": "哥布林的威脅",
  "stages": [
    { "type": "kill", "monster": "goblin", "count": 3, "desc": "擊敗巢穴的哥布林" },
    { "type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得哥布林信物" },
    { "type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "確認巢穴最深處" },
    { "type": "talk", "desc": "回橡鎮向守衛回報" }
  ],
  "rewards": { "gold": 100, "items": ["potion"] }
}
```

建立 `content/dialogues/qg_oak_guard.json`：

```json
{
  "id": "qg_oak_guard",
  "start": "root",
  "nodes": {
    "root": {
      "text": "守衛打量著你。",
      "choices": [
        { "text": "「哥布林的事，我來幫忙。」", "require": {"quest_inactive": "goblin_menace"},
          "effects": [{"op": "accept_quest", "quest": "goblin_menace"}], "goto": "accepted" },
        { "text": "「任務完成了，來回報。」", "require": {"quest_stage": {"id": "goblin_menace", "eq": 3}},
          "effects": [{"op": "advance_quest", "quest": "goblin_menace"}], "goto": "turned_in" },
        { "text": "「再會。」（已完成）", "require": {"quest_done": "goblin_menace"}, "goto": "thanks" },
        { "text": "離開", "goto": null }
      ]
    },
    "accepted": { "text": "守衛：「感謝！哥布林在東北野的巢穴，先去清掉牠們吧。」", "choices": [ {"text": "…", "goto": null} ] },
    "turned_in": { "text": "守衛：「你做到了！這點謝禮請收下。」", "choices": [ {"text": "…", "goto": null} ] },
    "thanks": { "text": "守衛：「橡鎮多虧有你。」", "choices": [ {"text": "…", "goto": null} ] }
  }
}
```

修改 `content/maps/town_oak.json`：在 `entities` 陣列加入一項（建議放在 scene 之後）：

```json
    { "type": "questgiver", "pos": [2, 1], "dialogue": "qg_oak_guard" },
```

修改 `content/maps/wild_ne.json`：把 `entities` 改為：

```json
  "entities": [
    { "type": "vendor", "pos": [2, 2], "id": "wandering_merchant" },
    { "type": "monster", "pos": [1, 1], "encounter": "g" },
    { "type": "chest", "pos": [3, 1], "items": ["lucky_charm"], "gold": 0 }
  ],
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/content/test_quest_content.gd -gexit`
Expected: PASS（4 測試綠）

- [ ] **Step 5: Commit**

```bash
git add content/quests/goblin_menace.json content/dialogues/qg_oak_guard.json content/maps/town_oak.json content/maps/wild_ne.json tests/content/test_quest_content.gd
git commit -m "feat(quest): demo 任務「哥布林的威脅」+ 守衛對話 + 地圖內容"
```

---

## Task 13: main.gd 接線（resolver / QuestLog / J / notify_*）

**Files:**
- Modify: `presentation/world/main.gd`

**說明**：main 無單元測試，以**全套 GUT 不退化** + **headless boot smoke** 把關，視覺驗收留人工 gate。

**Interfaces:**
- Consumes: `QuestCatalog.load_quest`、`QuestLog`、`GameState.notify_*` / `quests_changed`、`MapData.has_quest_giver`、`DialogueCatalog`、`DialogueRunner`、`Monster.monster_id`

- [ ] **Step 1: _ready 注入 resolver + 建 QuestLog + 連 signal**

在 `var _vendor_overlay: VendorOverlay` 之後加成員：

```gdscript
var _quest_log: QuestLog
```

在 `_ready()` 內 `_vendor_overlay` 區塊之後、`_menus = [...]` 之前加：

```gdscript
	_quest_log = QuestLog.new()
	add_child(_quest_log)
	_quest_log.closed.connect(_on_menu_closed)
	GameState.quest_resolver = Callable(QuestCatalog, "load_quest")
	GameState.quests_changed.connect(_on_quests_changed)
```

把 `_menus` 那行改成：

```gdscript
	_menus = [_save_menu, _inventory_menu, _spell_menu, _quest_log]
```

在 `_on_menu_closed` 之後加：

```gdscript
func _on_quests_changed() -> void:
	if _quest_log.is_open():
		_quest_log.refresh()
```

- [ ] **Step 2: _on_entered_cell 頂部餵 notify_enter / refresh_collect + dispatch 加 questgiver**

在 `_on_entered_cell` 內，`GameState.mark_explored(...)` 之後、`var link := ...` 之前加：

```gdscript
	GameState.notify_enter(GameState.current_map_id, pos)
	GameState.refresh_collect()
```

並在 dispatch 鏈中 `_try_scene(pos)` 與 `_try_vendor(pos)` 之間加：

```gdscript
	if _try_quest_giver(pos):
		return
```

在 `_try_scene` 之後加新方法（重用對話覆蓋層、可重複觸發、無 once）：

```gdscript
func _try_quest_giver(pos: Vector2i) -> bool:
	var map := MapManager.current_map
	if not map.has_quest_giver(pos):
		return false
	var entry := map.get_quest_giver(pos)
	var data := DialogueCatalog.load_dialogue(String(entry["dialogue"]))
	if data == null:
		GameState.message_log.push("（對話 %s 遺失）" % entry["dialogue"])
		return false
	_scene_once = false
	_player.set_enabled(false)
	_dialogue_overlay.open(DialogueRunner.new(data, GameState))
	return true
```

註：`_on_dialogue_finished` 已存在；questgiver 設 `_scene_once = false` 故不會誤標 scene-triggered。對話結束後玩家重新啟用沿用既有路徑。

- [ ] **Step 3: 對話結束補 refresh_collect（give op 可能給 collect 道具）**

在 `_on_dialogue_finished()` 內 `_player.set_enabled(true)` 之前加：

```gdscript
	GameState.refresh_collect()
```

- [ ] **Step 4: 戰鬥勝利餵 notify_kill + refresh_collect**

在 `_on_combat_finished` 的 VICTORY 分支，`_grant_drops()` 之後、`MapManager.current_map.clear_encounter(...)` 之前加：

```gdscript
		for m in _combat.monsters:
			GameState.notify_kill(m.monster_id)
		GameState.refresh_collect()
```

- [ ] **Step 5: 開寶箱後 refresh_collect**

在 `_on_chest_confirmed()` 內 `_player.set_enabled(true)` 之前加：

```gdscript
	GameState.refresh_collect()
```

- [ ] **Step 6: J 鍵開關任務日誌**

在 `_unhandled_input` 的按鍵分派，`elif event.keycode == KEY_M:` 區塊之後加：

```gdscript
	elif event.keycode == KEY_J:
		_toggle_menu(_quest_log)
```

- [ ] **Step 7: import + 全套測試 + headless boot smoke 確認不退化**

Run: `godot --headless --path . --import`
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全套 PASS（無退化；新增 quest 測試全綠）
Run: `godot --headless --path .`（boot smoke：載入 main 場景無腳本錯誤即可，數秒後 Ctrl-C 或讓其自然結束）
Expected: 無 parse/載入錯誤輸出

- [ ] **Step 8: Commit**

```bash
git add presentation/world/main.gd
git commit -m "feat(quest): main 接線（QuestLog/J、notify_enter/kill/collect、questgiver 開店）"
```

---

## 完工檢查（人工視覺 gate，`./run.sh`）

1. town_oak 踩 (2,1) 守衛 → 對話接任務 → 訊息列「接下任務：哥布林的威脅」；`J` 開日誌見「擊敗巢穴的哥布林 0/3」。
2. 出鎮到 wild_ne，踩 (1,1) → 與 3 隻哥布林戰鬥 → 勝利後日誌「擊敗… 3/3 → 取得哥布林信物 0/1」、訊息列階段 toast。
3. 踩 (3,1) 開寶箱拿 lucky_charm → collect 完成、進到「確認巢穴最深處」。
4. 走到 (3,3) → reach 完成、進到「回橡鎮向守衛回報」。
5. 回 town_oak 守衛 (2,1) → 選「回報」→ 任務完成 toast、金幣 +100、得 potion、日誌移到「已完成」。
6. 全程任一點存檔（Tab）→ 讀檔後任務進度/完成狀態還原（`J` 確認）。
7. 三選單 + 任務日誌互斥：戰鬥/對話/寶箱/商店進行中按 J 無效。

---

## Self-Review（plan 對 spec 覆蓋核對）

- 四型目標：QuestSystem(Task 2) + GameState 餵入(Task 8) + main 鉤子(Task 13) ✅
- 線性階段鏈、每階段一目標：QuestDef stages(Task 1)、`_advance`(Task 2) ✅
- 完成自動發獎、turn-in=最後 talk：`_advance`→done + `_grant_quest_rewards`(Task 8)、demo 對話 advance_quest(Task 12) ✅
- 對話接取/回報（effects/require）：Task 4/5 ✅
- 任務給予物件 questgiver（重用 DialogueOverlay）：Task 7 + main `_try_quest_giver`(Task 13) ✅
- 任務日誌面板(J) + 訊息列 toast：QuestLog(Task 11) + GameState push(Task 8) ✅
- 存檔 quests（VERSION 6）：Task 9 ✅
- demo「哥布林的威脅」操演四型：Task 12 ✅
- 測試：Task 1–12 皆含 GUT；main 以全套不退化 + boot smoke(Task 13) ✅
- collect「目前持有≥N」限制：demo 用 lucky_charm（非消耗/非起始）+ 階段順序 kill 先行避免一次性遭遇陷阱(Task 12 設計備忘) ✅
- 型別一致性：state `{status,stage,count}`、have_count=`Callable(inventory,"count_of")`、resolver=`Callable(QuestCatalog,"load_quest")` 全程一致 ✅
- 不需向後相容：Task 9 直接升 6 並**移除舊版接受清單**（只收 v6）；既有「載舊版」測試改寫為「目前版本缺欄→空」或「舊版被拒」（使用者 2026-06-26 拍板） ✅
```
