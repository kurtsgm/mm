# 怪物實例 UUID + UUID 制擊殺目標 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 每個地圖遇抵實例有穩定 UUIDv7；任務擊殺目標改成「對應一串遇抵 UUID、全部擊敗才算」，根治跨怪計數，並支援多目標。

**Architecture:** 新增 `Uuidv7` 產生器與 `assign_encounter_uuids` 工具（寫回地圖 JSON）；`MapData.encounter_uids` 存每格遇抵 uid；`GameState.defeated_encounters`（持久 set）取代 `kill_counts`；kill 階段 `targets:[uid]`，由 `QuestSystem` 對 `q.is_defeated(uid)` 判定全滿足。`/check-quest` 加 uid 驗證 + 整任務 flow 自動測試。

**Tech Stack:** Godot 4.7、GDScript、GUT、JSON 內容。

## Global Constraints

- **不需向後相容**：直接升 save VERSION 8、舊存檔不再載；一併改測試資料。
- **新增 class_name 腳本後先 `godot --headless --path . --import` 再跑 GUT**（global class cache + `.gd.uid`，`.gd.uid` 要 commit）。
- 三層分層：`engine/` 純（無節點/IO，除明確 util）、`content/` 資料、`presentation/`/`autoload/` glue。`GameState` 用注入 resolver、保持 catalog-free。
- 測試指令（godot 不在 PATH 時前置 `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`）：
  - 全套：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
  - 單檔：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/<路徑>/test_x.gd -gexit`
- 怪物型別 id：`goblin`/`ogre`；遇抵群組 id：`g`(=3 goblin)/`o`(=1 ogre)。
- **q（duck-typed 查詢）契約**：`q.item_count(id)->int`（collect）、`q.is_defeated(uid)->bool`（kill）。reach 走事件式 `advance_reach`、talk 走 `advance_talk`（皆不變）。

---

## 檔案結構

**新增**：`engine/util/uuidv7.gd`、`tools/assign_encounter_uuids.gd`、`engine/quest/quest_flow.gd`、`tests/engine/util/test_uuidv7.gd`、`tests/content/test_quest_flows.gd`、`tests/engine/combat/`（無）。
**修改**：`resources/map_data.gd`、`engine/map/map_importer.gd`、`autoload/game_state.gd`、`engine/quest/quest_system.gd`、`engine/quest/quest_progress.gd`、`engine/quest/quest_def.gd`、`engine/save/save_data.gd`、`engine/save/save_serializer.gd`、`autoload/save_system.gd`、`presentation/world/main.gd`、`tools/quest_lint.gd`、`tools/quest_lint_cli.gd`、`content/maps/town_oak.json`、`content/maps/wild_ne.json`、`content/quests/goblin_menace.json`、`.claude/skills/check-quest/SKILL.md` + 既有測試（kill 相關改寫、save 版本 7→8）。

---

## Task 1: Uuidv7 產生器

**Files:** Create `engine/util/uuidv7.gd`；Test `tests/engine/util/test_uuidv7.gd`

**Interfaces:** Produces `class_name Uuidv7`；`static func generate() -> String`（標準 36 字元 `8-4-4-4-12`，版本 7、變體 10）。

- [ ] **Step 1: 失敗測試** — `tests/engine/util/test_uuidv7.gd`：

```gdscript
extends GutTest

func test_format_length_and_dashes():
	var u := Uuidv7.generate()
	assert_eq(u.length(), 36)
	assert_eq(u[8], "-"); assert_eq(u[13], "-"); assert_eq(u[18], "-"); assert_eq(u[23], "-")

func test_version_and_variant_nibbles():
	var u := Uuidv7.generate()
	assert_eq(u[14], "7", "版本 nibble 應為 7")
	assert_true("89ab".contains(u[19]), "變體 nibble 應為 8/9/a/b")

func test_unique_batch():
	var seen := {}
	for i in 200:
		var u := Uuidv7.generate()
		assert_false(seen.has(u), "重複 uid")
		seen[u] = true
```

- [ ] **Step 2: 跑→失敗**：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/engine/util/test_uuidv7.gd -gexit` → FAIL（Uuidv7 未定義）

- [ ] **Step 3: 實作** — `engine/util/uuidv7.gd`：

```gdscript
class_name Uuidv7
extends Object
# UUIDv7：48-bit 毫秒時戳 + 版本 7 + 變體 10 + 隨機。標準 8-4-4-4-12 小寫十六進位。

static func generate() -> String:
	var ms := int(Time.get_unix_time_from_system() * 1000.0)
	var b := PackedByteArray()
	b.resize(16)
	b[0] = (ms >> 40) & 0xFF
	b[1] = (ms >> 32) & 0xFF
	b[2] = (ms >> 24) & 0xFF
	b[3] = (ms >> 16) & 0xFF
	b[4] = (ms >> 8) & 0xFF
	b[5] = ms & 0xFF
	for i in range(6, 16):
		b[i] = randi() & 0xFF
	b[6] = (b[6] & 0x0F) | 0x70   # version 7
	b[8] = (b[8] & 0x3F) | 0x80   # variant 10
	var h := ""
	for x in b:
		h += "%02x" % x
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
```

- [ ] **Step 4: import + 跑→通過**：`godot --headless --path . --import` 然後單檔測試 → PASS（3 測試）

- [ ] **Step 5: Commit**：`git add engine/util/uuidv7.gd engine/util/uuidv7.gd.uid tests/engine/util/test_uuidv7.gd tests/engine/util/test_uuidv7.gd.uid && git commit -m "feat(quest): Uuidv7 產生器"`

---

## Task 2: MapData.encounter_uids + importer 解析

**Files:** Modify `resources/map_data.gd`、`engine/map/map_importer.gd`；Test `tests/resources/test_map_data.gd`、`tests/engine/map/test_map_importer.gd`

**Interfaces:** Produces `MapData.encounter_uids: Dictionary`（Vector2i→String uid）+ `get_encounter_uid(pos)->String`；importer 讀 monster `id`→`encounter_uids[pos]`（缺→""）。

- [ ] **Step 1: 失敗測試** — `tests/resources/test_map_data.gd` 加：

```gdscript
func test_encounter_uid_accessor():
	var m := MapData.new()
	m.encounter_uids = {Vector2i(1, 1): "u-abc"}
	assert_eq(m.get_encounter_uid(Vector2i(1, 1)), "u-abc")
	assert_eq(m.get_encounter_uid(Vector2i(0, 0)), "")
```

`tests/engine/map/test_map_importer.gd` 加：

```gdscript
func test_monster_id_to_encounter_uid():
	var json := '{"grid":["@."],"entities":[{"type":"monster","pos":[1,0],"encounter":"g","id":"u-1"}]}'
	var map := MapImporter.parse(json)
	assert_eq(map.get_encounter(Vector2i(1, 0)), "g")
	assert_eq(map.get_encounter_uid(Vector2i(1, 0)), "u-1")

func test_monster_without_id_uid_empty():
	var json := '{"grid":["@."],"entities":[{"type":"monster","pos":[1,0],"encounter":"g"}]}'
	var map := MapImporter.parse(json)
	assert_eq(map.get_encounter_uid(Vector2i(1, 0)), "")
```

- [ ] **Step 2: 跑→失敗**（兩檔）→ FAIL（encounter_uids/get_encounter_uid 不存在）

- [ ] **Step 3: 實作**
`resources/map_data.gd`：在 `@export var encounters` 之後加 `@export var encounter_uids: Dictionary = {}  # Vector2i -> String uid`；在 `clear_encounter` 之後加：

```gdscript
func get_encounter_uid(pos: Vector2i) -> String:
	return encounter_uids.get(pos, "")
```

`engine/map/map_importer.gd`：
- `_parse_entities` 區域變數加 `var encounter_uids := {}`（在 `var encounters := {}` 之後）。
- `"monster":` 分支改：

```gdscript
			"monster":
				if not e.has("encounter"):
					return null
				encounters[pos] = String(e["encounter"])
				encounter_uids[pos] = String(e.get("id", ""))
```
- 回傳 dict 加 `"encounter_uids": encounter_uids`。
- `parse()` 指派區加 `map.encounter_uids = entities["encounter_uids"]`。

- [ ] **Step 4: import + 跑→通過**（兩檔）

- [ ] **Step 5: Commit**：`git add resources/map_data.gd engine/map/map_importer.gd tests/resources/test_map_data.gd tests/engine/map/test_map_importer.gd && git commit -m "feat(quest): MapData.encounter_uids + importer 解析 monster id"`

---

## Task 3: assign_encounter_uuids 工具 + 回填地圖

**Files:** Create `tools/assign_encounter_uuids.gd`；Modify（執行產物）`content/maps/town_oak.json`、`content/maps/wild_ne.json`（+ 任何含 monster 的圖）

**Interfaces:** Consumes `Uuidv7`。Produces：所有 `monster` entity 都有非空唯一 `id`（寫回 JSON）。

- [ ] **Step 1: 寫工具** — `tools/assign_encounter_uuids.gd`：

```gdscript
extends SceneTree
# 給 content/maps/*.json 中缺 id 的 monster entity 補 UUIDv7 並寫回（重排版）。
# 執行：godot --headless --path . --script res://tools/assign_encounter_uuids.gd
func _initialize() -> void:
	var dir := "res://content/maps"
	var da := DirAccess.open(dir)
	var changed := 0
	for f in da.get_files():
		if not f.ends_with(".json"):
			continue
		var path := "%s/%s" % [dir, f]
		var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var modified := false
		for e in raw.get("entities", []):
			if typeof(e) == TYPE_DICTIONARY and String(e.get("type", "")) == "monster" and String(e.get("id", "")) == "":
				e["id"] = Uuidv7.generate()
				modified = true
		if modified:
			var fw := FileAccess.open(path, FileAccess.WRITE)
			fw.store_string(JSON.stringify(raw, "\t"))
			fw.close()
			changed += 1
			print("uid 補入：", f)
	print("完成，更新 %d 張圖" % changed)
	quit()
```

- [ ] **Step 2: import + 執行工具**：
`godot --headless --path . --import`
`godot --headless --path . --script res://tools/assign_encounter_uuids.gd`
Expected：印「uid 補入：town_oak.json」「uid 補入：wild_ne.json」（含 monster 的圖）。

- [ ] **Step 3: 確認 + 記下 uid**：
`grep -A1 '"type": "monster"' content/maps/wild_ne.json content/maps/town_oak.json`
記下 **wild_ne (1,1) 的 id**（Task 9 要用）與 town_oak (3,1) 的 id（應彼此不同）。確認全套測試仍綠（地圖重排版後 importer 仍可解析）：跑全套。

- [ ] **Step 4: Commit**：`git add tools/assign_encounter_uuids.gd content/maps/ && git commit -m "feat(quest): assign_encounter_uuids 工具 + 回填地圖遇抵 uid"`

---

## Task 4: QuestDef kill targets 解析

**Files:** Modify `engine/quest/quest_def.gd`；Test `tests/engine/quest/test_quest_def.gd`

**Interfaces:** Produces kill 階段正規化 `{type:"kill", targets:Array[String], desc}`；空/非陣列 targets → parse 回 null。

- [ ] **Step 1: 改測試** — `tests/engine/quest/test_quest_def.gd`：把 `_raw()` 的 kill 階段改成 targets，並改/加斷言：
  - `_raw()` 內 `{"type": "kill", "monster": "goblin", "count": 3, ...}` → `{"type": "kill", "targets": ["u-1", "u-2"], "desc": "擊敗哥布林"}`。
  - `test_kill_fields` 改成：`assert_eq(d.stage(1)["targets"], ["u-1", "u-2"])`。
  - 加 `test_kill_empty_targets_rejected()`：

```gdscript
func test_kill_empty_targets_rejected():
	var r := _raw(); r["stages"] = [{"type": "kill", "targets": [], "desc": "x"}]
	assert_null(QuestDef.parse(r))

func test_kill_non_array_targets_rejected():
	var r := _raw(); r["stages"] = [{"type": "kill", "targets": "u-1", "desc": "x"}]
	assert_null(QuestDef.parse(r))
```

- [ ] **Step 2: 跑→失敗**（targets 尚未支援；原 kill 解析期望 monster/count）

- [ ] **Step 3: 實作** — `engine/quest/quest_def.gd` `_parse_stage` 的 `"kill":` 分支整段換成：

```gdscript
		"kill":
			var targets = rs.get("targets", null)
			if typeof(targets) != TYPE_ARRAY or targets.is_empty():
				return {}
			var ts: Array = []
			for t in targets:
				ts.append(String(t))
			return {"type": "kill", "targets": ts, "desc": desc}
```

- [ ] **Step 4: 跑→通過**

- [ ] **Step 5: Commit**：`git add engine/quest/quest_def.gd tests/engine/quest/test_quest_def.gd && git commit -m "feat(quest): QuestDef kill 改 targets:[uid]"`

---

## Task 5: QuestSystem + QuestProgress kill 改 by-uid

**Files:** Modify `engine/quest/quest_system.gd`、`engine/quest/quest_progress.gd`；Test `tests/engine/quest/test_quest_system.gd`、`tests/engine/quest/test_quest_progress.gd`

**Interfaces:** Consumes `q.is_defeated(uid)->bool`。Produces kill 滿足＝所有 targets 都 is_defeated；progress「<desc> X/N」。

- [ ] **Step 1: 改測試**
`tests/engine/quest/test_quest_system.gd`：`FakeQ` 把 `kills`/`kill_count` 換成 defeated set：

```gdscript
class FakeQ:
	var items: Dictionary = {}
	var defeated: Dictionary = {}   # uid -> true
	func item_count(id: String) -> int: return int(items.get(id, 0))
	func is_defeated(uid: String) -> bool: return defeated.has(uid)
```
`_def()` 的 kill 階段改 `{"type": "kill", "targets": ["u-a", "u-b"], "desc": "擊敗"}`。把用到 `q.kills`/`kill_count` 的 kill 測試改成 defeated，例如：

```gdscript
func test_kill_all_targets_defeated():
	var q := FakeQ.new(); q.defeated["u-a"] = true; q.defeated["u-b"] = true
	var s := QuestSystem.catch_up(_def(), {"status": "active", "stage": 1}, q)
	assert_eq(s["stage"], 2)   # kill 全滿足 → 到 collect

func test_kill_partial_targets_not_satisfied():
	var q := FakeQ.new(); q.defeated["u-a"] = true   # 缺 u-b
	var s := QuestSystem.catch_up(_def(), {"status": "active", "stage": 1}, q)
	assert_eq(s["stage"], 1)
```
（移除/改寫舊的 `test_kill_state_based_absolute` 等用 kills 的測試；`test_advance_reach_matching_then_chains` 的 `q.kills["goblin"]=3` 改成 `q.defeated["u-a"]=true; q.defeated["u-b"]=true`，使 reach 後 catch_up 能過 kill→collect。`is_stage_satisfied` 測試對 kill：`assert_true(QuestSystem.is_stage_satisfied(_def().stage(1), q_with_both))`。）

`tests/engine/quest/test_quest_progress.gd`：`FakeQ` 同樣改成 `items`+`defeated`+`is_defeated`；`_def()` kill 改 targets `["u-a","u-b","u-c"]`；`test_kill_line_shows_count` 改：

```gdscript
func test_kill_line_shows_defeated_count():
	var q := FakeQ.new(); q.defeated["u-a"] = true
	assert_eq(QuestProgress.stage_line(_def(), {"status": "active", "stage": 0}, q), "擊敗哥布林 1/3")
```
（移除 `test_kill_line_clamped_to_target`。）

- [ ] **Step 2: 跑→失敗**（兩檔；q.is_defeated 未被使用、stage_line/ is_stage_satisfied 還在用 kill_count）

- [ ] **Step 3: 實作**
`engine/quest/quest_system.gd` `is_stage_satisfied` 的 `"kill":` 分支換成：

```gdscript
		"kill":
			for t in stage.get("targets", []):
				if not q.is_defeated(String(t)):
					return false
			return true
```
`engine/quest/quest_progress.gd` `stage_line` 的 `"kill":` 分支換成：

```gdscript
		"kill":
			var targets: Array = st.get("targets", [])
			var done := 0
			for t in targets:
				if q.is_defeated(String(t)):
					done += 1
			return "%s %d/%d" % [desc, done, targets.size()]
```

- [ ] **Step 4: 跑→通過**（兩檔）

- [ ] **Step 5: Commit**：`git add engine/quest/quest_system.gd engine/quest/quest_progress.gd tests/engine/quest/ && git commit -m "feat(quest): kill 改 by-uid（QuestSystem 全 target 滿足 + Progress X/N）"`

---

## Task 6: GameState defeated_encounters（取代 kill_counts/notify_kill）

**Files:** Modify `autoload/game_state.gd`；Test `tests/autoload/test_game_state_quests.gd`

**Interfaces:** Consumes `QuestSystem`/`QuestProgress`（kill by-uid）、`QuestDef`（targets）。Produces `GameState`：`var defeated_encounters`、`is_defeated(uid)`、`mark_encounter_defeated(uid)`、`notify_encounter_defeated(uid)`；移除 `kill_counts`/`kill_count`/`notify_kill`。

- [ ] **Step 1: 改測試** — 改寫 `tests/autoload/test_game_state_quests.gd`：
  - `before_each` 的 `_def` kill 階段改 `{"type": "kill", "targets": ["u-wild"], "desc": "擊敗"}`（順序仍 kill→collect→reach→talk）。
  - `test_notify_kill_increments_tally_without_quest` → 改成：

```gdscript
func test_mark_defeated_records_uid():
	var gs = _gs()
	gs.mark_encounter_defeated("u-wild")
	assert_true(gs.is_defeated("u-wild"))
```
  - `test_full_flow_completes_and_rewards`：把 `gs.notify_kill("goblin"); gs.notify_kill("goblin")` 換成 `gs.notify_encounter_defeated("u-wild")`；其後階段不變（collect→reach→talk）。
  - `test_kill_collect_before_accept_credited_stops_at_reach`：把 notify_kill×2 換成 `gs.notify_encounter_defeated("u-wild")`（接取前擊敗該遇抵 → 追認 kill）。
  - 新增**使用者回報流程迴歸**：

```gdscript
func test_defeating_other_encounter_does_not_satisfy():
	var gs = _gs()
	gs.accept_quest("q")
	gs.notify_encounter_defeated("u-town")   # 別的遇抵（城鎮）
	assert_eq(gs.quest_stage("q"), 0)         # kill 未滿足、仍在 kill
	gs.notify_encounter_defeated("u-wild")    # 正確遇抵
	assert_eq(gs.quest_stage("q"), 1)         # → collect
```
  - `test_xp_reward_...`：把 notify_kill×2 換成 `gs.notify_encounter_defeated("u-wild")`。

- [ ] **Step 2: 跑→失敗**（notify_encounter_defeated/is_defeated/mark 不存在）

- [ ] **Step 3: 實作** — `autoload/game_state.gd`：
  - 變數區：`var kill_counts...` 那行換成 `var defeated_encounters: Dictionary = {}   # uid -> true（持久；擊敗的遇抵實例）`。
  - 移除 `func kill_count(...)`（lines ~101-102）。
  - 在 `item_count` 之後加：

```gdscript
func is_defeated(uid: String) -> bool:
	return defeated_encounters.has(uid)

func mark_encounter_defeated(uid: String) -> void:
	if uid != "":
		defeated_encounters[uid] = true
```
  - `notify_kill(...)` 整個函式換成：

```gdscript
# 戰鬥勝利時呼叫：記下該遇抵 uid 為已擊敗，再重新評估所有任務。
func notify_encounter_defeated(uid: String) -> void:
	mark_encounter_defeated(uid)
	for id in quests.keys():
		_run_quest(id, "recheck")
```

- [ ] **Step 4: import + 跑→通過**

- [ ] **Step 5: Commit**：`git add autoload/game_state.gd tests/autoload/test_game_state_quests.gd && git commit -m "feat(quest): GameState defeated_encounters 取代 kill_counts（by-uid 擊敗追蹤）"`

---

## Task 7: 存檔 v8（defeated_encounters，移除 kill_counts）

**Files:** Modify `engine/save/save_data.gd`、`engine/save/save_serializer.gd`、`autoload/save_system.gd`；Test `tests/engine/save/test_save_serializer_quests.gd` + 版本斷言三檔

**Interfaces:** Produces `SaveData.defeated_encounters`、序列化 `state.defeated_encounters`（uid 陣列）、`VERSION==8`、移除 `kill_counts`。

- [ ] **Step 1: 改測試** — `tests/engine/save/test_save_serializer_quests.gd`：
  - `_data()` 把 `d.kill_counts = {...}` 換成 `d.defeated_encounters = {"u-a": true, "u-b": true}`。
  - `test_kill_counts_round_trip`/`test_kill_counts_absent_is_empty` → 改成 defeated_encounters：

```gdscript
func test_defeated_encounters_round_trip():
	var raw := SaveSerializer.to_dict(_data())
	var back := SaveSerializer.from_dict(raw)
	assert_true(back.defeated_encounters.has("u-a"))
	assert_true(back.defeated_encounters.has("u-b"))

func test_defeated_encounters_absent_is_empty():
	var raw := SaveSerializer.to_dict(_data())
	raw["state"].erase("defeated_encounters")
	assert_eq(SaveSerializer.from_dict(raw).defeated_encounters, {})
```
  - `test_version_is_7` → `test_version_is_8` / 斷言 8；`test_old_version_rejected` 的 `raw["version"]=6` 改 `=7`。
  - 版本斷言三檔：`test_save_serializer.gd` `test_to_dict_version_is_7`→8、`test_save_serializer_flags.gd` `test_version_is_7`→8、`test_save_serializer_spells.gd` `test_version_is_7`→8（函式名與斷言值都改 8）。

- [ ] **Step 2: 跑→失敗**

- [ ] **Step 3: 實作**
`engine/save/save_data.gd`：`var kill_counts...` 換成 `var defeated_encounters: Dictionary = {}  # uid -> true`。
`engine/save/save_serializer.gd`：
- `const VERSION := 7` → `8`。
- to_dict：`"kill_counts": _kill_counts_to_dict(data.kill_counts),` 換成 `"defeated_encounters": data.defeated_encounters.keys(),`。
- from_dict：`data.kill_counts = _kill_counts_from_dict(...)` 換成 `data.defeated_encounters = _flags_from_array(s.get("defeated_encounters", []))`。
- 移除 `_kill_counts_to_dict`/`_kill_counts_from_dict` 兩函式（`_flags_from_array` 既有、回 {key:true}，重用）。
`autoload/save_system.gd`：`data.kill_counts = gs.kill_counts` → `data.defeated_encounters = gs.defeated_encounters`；`gs.kill_counts = data.kill_counts` → `gs.defeated_encounters = data.defeated_encounters`。

- [ ] **Step 4: 跑全套 save 目錄→通過**：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine/save -ginclude_subdirs -gexit`

- [ ] **Step 5: Commit**：`git add engine/save/ autoload/save_system.gd tests/engine/save/ && git commit -m "feat(quest): 存檔 v8 defeated_encounters（移除 kill_counts）"`

---

## Task 8: main.gd 戰鬥勝利接線

**Files:** Modify `presentation/world/main.gd`

**Interfaces:** Consumes `GameState.notify_encounter_defeated`、`MapData.get_encounter_uid`。

- [ ] **Step 1: 改實作** — `_on_combat_finished` VICTORY 分支，把：

```gdscript
		for m in _combat.monsters:
			GameState.notify_kill(m.monster_id)
		GameState.refresh_collect()
```
換成：

```gdscript
		GameState.notify_encounter_defeated(MapManager.current_map.get_encounter_uid(_combat_pos))
		GameState.refresh_collect()
```

- [ ] **Step 2: import + 全套 + headless boot**：
全套 PASS（main 無單元測試、數量不變）；`godot --headless --path .`（3 秒）無 SCRIPT ERROR。

- [ ] **Step 3: Commit**：`git add presentation/world/main.gd && git commit -m "feat(quest): main 戰勝以遇抵 uid 記擊敗（取代 notify_kill）"`

---

## Task 9: demo goblin_menace 指向野外遇抵 uid + 內容測試

**Files:** Modify `content/quests/goblin_menace.json`；Test `tests/content/test_quest_content.gd`

**Interfaces:** Consumes Task 3 寫入的 `wild_ne (1,1)` uid。

- [ ] **Step 1: 讀 uid**：`grep -A2 '"pos": \[1, 1\]' content/maps/wild_ne.json`（或 `grep -B1 -A2 monster content/maps/wild_ne.json`）取得 wild_ne (1,1) monster 的 `id`（記為 `<WILD_UID>`）。同樣取 town_oak (3,1) 的 `id`（`<TOWN_UID>`）確認不同。

- [ ] **Step 2: 改 demo quest** — `content/quests/goblin_menace.json` 的 kill 階段：

```json
    { "type": "kill", "targets": ["<WILD_UID>"], "desc": "擊敗巢穴的哥布林" },
```
（把 `<WILD_UID>` 換成上一步的實際 uid。）

- [ ] **Step 3: 改測試** — `tests/content/test_quest_content.gd` 的 `test_goblin_menace_loads`：stage(0) 仍 `type=="kill"`，加：

```gdscript
	# kill 目標＝野外遇抵 uid，且非城鎮遇抵 uid（不會被城鎮哥布林滿足）
	var ne := MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/wild_ne.json"))
	var oak := MapImporter.parse(FileAccess.get_file_as_string("res://content/maps/town_oak.json"))
	var wild_uid := ne.get_encounter_uid(Vector2i(1, 1))
	assert_eq(d.stage(0)["targets"], [wild_uid])
	assert_ne(wild_uid, oak.get_encounter_uid(Vector2i(3, 1)))
	assert_ne(wild_uid, "")
```

- [ ] **Step 4: 跑→通過**：`-gtest=res://tests/content/test_quest_content.gd`

- [ ] **Step 5: Commit**：`git add content/quests/goblin_menace.json tests/content/test_quest_content.gd && git commit -m "feat(quest): goblin_menace 擊殺改指向野外遇抵 uid"`

---

## Task 10: /check-quest uid 驗證

**Files:** Modify `tools/quest_lint.gd`；Test `tests/content/test_quest_lint.gd`（沿用，斷言 0 error）

**Interfaces:** Consumes `MapData.encounter_uids`、`QuestDef`（targets）。

- [ ] **Step 1: 實作** — `tools/quest_lint.gd`：
  - 新增收集全地圖遇抵 uid 的輔助 + 唯一性檢查：

```gdscript
static func _encounter_uids(errors: Array) -> Dictionary:
	var seen := {}   # uid -> "map:pos"
	for mid in _json_ids(MAPS_DIR):
		var map = MapImporter.parse(FileAccess.get_file_as_string("%s/%s.json" % [MAPS_DIR, mid]))
		if map == null:
			continue
		for pos in map.encounter_uids:
			var uid := String(map.encounter_uids[pos])
			if uid == "":
				errors.append("[map] %s 遇抵@%s 缺 id（跑 assign_encounter_uuids）" % [mid, pos])
				continue
			if seen.has(uid):
				errors.append("[map] 遇抵 uid 重複：%s（%s 與 %s:%s）" % [uid, seen[uid], mid, pos])
			seen[uid] = "%s:%s" % [mid, pos]
	return seen
```
  - `run()` 內取得 `var uids := _encounter_uids(errors)` 後傳入 `_check_stages`。
  - `_check_stages` 的 `"kill":` 分支改成驗 targets：

```gdscript
				"kill":
					var targets = st.get("targets", [])
					if typeof(targets) != TYPE_ARRAY or targets.is_empty():
						errors.append("[quest] %s 階段%d kill 缺 targets" % [qid, i])
					else:
						for t in targets:
							if not uids.has(String(t)):
								errors.append("[quest] %s 階段%d kill target '%s' 找不到對應遇抵 uid" % [qid, i, t])
```
  （`_check_stages` 簽章加 `uids: Dictionary` 參數；呼叫端傳入。移除舊的 monster-id 檢查。）

- [ ] **Step 2: import + 跑 lint 測試 + CLI**：
`tests/content/test_quest_lint.gd` 應仍 0 error（demo 內容已正確）。
`godot --headless --path . --script res://tools/quest_lint_cli.gd` → 0 error。

- [ ] **Step 3: Commit**：`git add tools/quest_lint.gd && git commit -m "feat(quest): check-quest 驗證 kill targets↔遇抵 uid + uid 唯一"`

---

## Task 11: 整任務 flow 自動測試 + CLI/SKILL

**Files:** Create `engine/quest/quest_flow.gd`、`tests/content/test_quest_flows.gd`；Modify `tools/quest_lint_cli.gd`、`.claude/skills/check-quest/SKILL.md`

**Interfaces:** Produces `class_name QuestFlow`；`static func simulate(gs, def, qid: String) -> Dictionary`（回 `{completed:bool}`）。

- [ ] **Step 1: 失敗測試** — `tests/content/test_quest_flows.gd`：

```gdscript
extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

func _quest_ids() -> Array:
	var out: Array = []
	var da := DirAccess.open("res://content/quests")
	if da:
		for f in da.get_files():
			if f.ends_with(".json"):
				out.append(f.get_basename())
	return out

func test_all_quests_completable_end_to_end():
	for qid in _quest_ids():
		var def = QuestCatalog.load_quest(qid)
		assert_not_null(def, "quest %s 載入失敗" % qid)
		var gs = GameStateScript.new()
		add_child_autofree(gs)
		gs.quest_resolver = Callable(QuestCatalog, "load_quest")
		var r = QuestFlow.simulate(gs, def, qid)
		assert_true(r["completed"], "quest %s 無法端到端跑通" % qid)
```

- [ ] **Step 2: 跑→失敗**（QuestFlow 未定義）

- [ ] **Step 3: 實作** — `engine/quest/quest_flow.gd`：

```gdscript
class_name QuestFlow
extends Object
# 模擬把一條任務從接取驅動到完成（happy path）：每階段觸發對應 GameState 事件。
# 給 /check-quest 與迴歸測試用。回 { completed:bool }。

static func simulate(gs, def, qid: String) -> Dictionary:
	gs.accept_quest(qid)
	var guard := 0
	while gs.is_quest_active(qid) and guard < 50:
		guard += 1
		var idx := gs.quest_stage(qid)
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
```

- [ ] **Step 4: import + 跑→通過**（goblin_menace + wild_message 皆跑通）

- [ ] **Step 5: CLI + SKILL**：
`tools/quest_lint_cli.gd`：在印完 lint 報告後加 flow 區段（每個 quest 建一個 gs 模擬）：

```gdscript
	print("--- 任務 flow 自動跑通 ---")
	var flow_fail := 0
	var da := DirAccess.open("res://content/quests")
	if da:
		for f in da.get_files():
			if not f.ends_with(".json"):
				continue
			var qid := f.get_basename()
			var def = QuestCatalog.load_quest(qid)
			if def == null:
				continue
			var gs = load("res://autoload/game_state.gd").new()
			root.add_child(gs)
			gs.quest_resolver = Callable(QuestCatalog, "load_quest")
			var ok: bool = QuestFlow.simulate(gs, def, qid)["completed"]
			print(("✓" if ok else "✗"), " flow ", qid)
			if not ok:
				flow_fail += 1
			gs.queue_free()
	if flow_fail > 0:
		print("ERROR  %d 個任務 flow 跑不通" % flow_fail)
```
並把結尾 `quit(...)` 的條件改成 `errors 或 flow_fail`：把 `_initialize` 開頭算 errors 的退出邏輯改為先存 `var had_err := not errors.is_empty()`，最後 `quit(1 if (had_err or flow_fail > 0) else 0)`。
`.claude/skills/check-quest/SKILL.md`：在「它檢查什麼」加一條「**整任務 flow 自動跑通**：每個 quest 模擬接取→各階段→完成,跑不通報 ERROR」;在排查對照註明 flow 失敗代表某階段無法被標準事件滿足（如 kill targets 指錯 uid、reach 格不可走）。

- [ ] **Step 6: import + 全套 + CLI dogfood**：全套 PASS;CLI 印 `✓ flow goblin_menace`、`✓ flow wild_message`、0 error。

- [ ] **Step 7: Commit**：`git add engine/quest/quest_flow.gd engine/quest/quest_flow.gd.uid tests/content/test_quest_flows.gd tests/content/test_quest_flows.gd.uid tools/quest_lint_cli.gd .claude/skills/check-quest/SKILL.md && git commit -m "feat(quest): 整任務 flow 自動測試（QuestFlow）+ check-quest CLI/skill 納入"`

---

## Self-Review（plan 對 spec 覆蓋）

- Uuidv7 產生器：Task 1 ✅
- 遇抵 uid（map/MapData/importer）：Task 2 ✅；指派工具+回填：Task 3 ✅
- kill targets（QuestDef/System/Progress）：Task 4/5 ✅
- defeated_encounters 取代 kill_counts（GameState）：Task 6 ✅；存檔 v8：Task 7 ✅
- main 戰勝以 uid 記擊敗：Task 8 ✅
- demo 指向野外 uid + town≠wild：Task 9 ✅
- check-quest uid 驗證：Task 10 ✅；flow 自動測試（含使用者流程精神）：Task 11 + 使用者回報迴歸在 Task 6（`test_defeating_other_encounter_does_not_satisfy`）✅
- 移除型別計數、不需向後相容（v8 棄舊檔）：Task 6/7 ✅
- 型別一致：q 契約 `item_count`/`is_defeated`；kill state `{type,targets,desc}`;defeated set `{uid:true}`;全程一致 ✅
