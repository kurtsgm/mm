# M5a「存檔系統」Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立多槽 JSON 存讀檔：純邏輯的 `SaveData`/`SaveSerializer`（roundtrip TDD），`SaveSystem` autoload 負責 `user://` 磁碟 IO 與 GameState/MapManager 接合，最後以程式建構的 `SaveMenu` 由 `main.gd` 接線，能存／讀／刪 5 個存檔槽並還原隊伍／金錢／座標／面向與已清遭遇。

**Architecture:** 三層分離。`SaveData`（RefCounted 快照）+ `SaveSerializer`（純靜態 to_dict/from_dict，**架構文件指名的 roundtrip TDD 對象**）放 `engine/save/`，零 Godot 視覺節點依賴。`SaveSystem` autoload 做 FileAccess/JSON 與槽位管理、並提供注入式 `capture_from`/`apply_to`（吃 GameState/MapManager 實例，可單元測試）+ 薄的全域包裝；讀檔成功後 emit `loaded`，**自己不重建 3D 世界**。玩家座標／面向／當前地圖 id／已清遭遇全部提升進 `GameState` 作單一真實來源，`main.gd` 透過既有 `entered_cell`/`facing_changed` 訊號同步。`SaveMenu` 與 `main.gd` 接線屬呈現層，手動驗證，比照 M1–M4 的 `Hud`/`CombatLayer`。

**Tech Stack:** Godot 4.2（GL Compatibility）、GDScript、GUT 9.x。

## Global Constraints

- 引擎語言一律 **GDScript**（不混 C#）。
- 引擎層（`res://engine/`）**不得**直接依賴 Godot 視覺節點；`SaveData`/`SaveSerializer` 只用純資料型別（`RefCounted`/`Object`/`Resource`/`Vector2i`/`Dictionary`）。
- **存檔格式既定**：JSON、存於 `user://saves/slot_<n>.json`、**固定 5 槽（slot 0–4）**、內容以 id 參照（地圖等靜態內容不入存檔）。
- **JSON 數字回讀一律是 `float`**：`JSON.parse_string` 把所有數字解析成 float。凡從 raw dict 取數值（含 `Vector2i` 的 `[x,y]`、enum、HP 等）**一律用 `int(...)` 轉**，否則型別不符。
- **時間戳由 autoload 蓋章，不進純序列化器**：`saved_at` 由 `SaveSystem.write_slot` 寫入（用 `Time.get_datetime_string_from_system()`），讓 `SaveSerializer` 保持決定性、可重現、roundtrip 可測。
- **玩家座標單一真實來源 = `GameState`**：`current_map_id` / `player_pos` / `player_facing` / `cleared_encounters` 住在 `GameState`；引擎存檔層不得反向讀取 `PlayerController`（呈現層）。
- **加法式修改既有檔，既有測試須保持全綠**：本案只**改** `autoload/game_state.gd`、`autoload/map_manager.gd`、`presentation/world/main.gd`、`project.godot`，且只增不破壞既有行為。**不得修改**：`engine/grid/*`、`engine/map/*`、`engine/party/*`、`engine/combat/*`、`engine/log/*`、`resources/*`、`presentation/world/player_controller.gd`、`presentation/world/world_builder.gd`、`presentation/ui/hud.gd`、`presentation/combat/*`。
- 格子座標約定：`Vector2i(x, y)`，東 +x、南 +y、北 -y。方向 enum `GridDirection.Dir { NORTH=0, EAST=1, SOUTH=2, WEST=3 }`。
- Condition 型別固定（沿用 M3）：`Character.Condition { OK=0, UNCONSCIOUS=1, DEAD=2 }`。
- 渲染後端固定 **GL Compatibility**（不改 `project.godot` 的 `[rendering]`）。
- 每完成一個 Task 就 commit 一次，前綴 `feat:`／`test:`／`chore:`。每個 commit 用 `git add -A`（`.gitignore` 已排除 `.godot/`；`.gd.uid` 一併入版控）。

**測試指令（每個 TDD Task 都用這條跑全測試）：**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

新增 `class_name`（`SaveData`/`SaveSerializer`/`SaveMenu`）若出現 `Identifier "..." not declared`，先跑一次 `godot --headless --path . --import` 再重跑測試。

---

### Task 1：`GameState` 狀態擴充（座標 + 已清遭遇）

把存檔需要的進度狀態加進 `GameState`：當前地圖 id、玩家座標／面向、已清遭遇集合，以及標記／查詢已清遭遇的輔助函式。純資料 + 邏輯，可用 newing 出來的實例測。

**Files:**
- Modify: `autoload/game_state.gd`
- Test: `tests/autoload/test_game_state.gd`（既有檔，**新增** test func，不動既有的）

**Interfaces:**
- Consumes：`GridDirection.Dir`（既有 global class）。
- Produces：`GameState` 新欄位 `current_map_id: String`、`player_pos: Vector2i`、`player_facing: int`、`cleared_encounters: Dictionary`（`String map_id -> Array`，每個 element 是 `Vector2i`）；新函式 `mark_encounter_cleared(map_id: String, pos: Vector2i) -> void`、`cleared_for(map_id: String) -> Array`。

- [ ] **Step 1：在 `tests/autoload/test_game_state.gd` 末尾新增失敗測試**

```gdscript
func _fresh_gs() -> Node:
	var gs = GameStateScript.new()
	add_child_autofree(gs)  # 進 tree → 觸發 _ready
	return gs

func test_location_defaults():
	var gs = _fresh_gs()
	assert_eq(gs.current_map_id, "")
	assert_eq(gs.player_pos, Vector2i.ZERO)
	assert_eq(gs.player_facing, GridDirection.Dir.NORTH)
	assert_eq(gs.cleared_encounters.size(), 0)

func test_mark_and_query_cleared_encounters():
	var gs = _fresh_gs()
	gs.mark_encounter_cleared("level01", Vector2i(4, 2))
	gs.mark_encounter_cleared("level01", Vector2i(4, 2))  # 重複 → 去重
	gs.mark_encounter_cleared("level01", Vector2i(7, 9))
	var list: Array = gs.cleared_for("level01")
	assert_eq(list.size(), 2)
	assert_true(list.has(Vector2i(4, 2)))
	assert_true(list.has(Vector2i(7, 9)))
	assert_eq(gs.cleared_for("nope").size(), 0)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：新測試 FAIL（`current_map_id` 等 invalid get / 找不到方法）；既有 `test_ready_builds_default_party_and_log` 仍 PASS。

- [ ] **Step 3：擴充 `autoload/game_state.gd`**

在既有欄位下方新增欄位與函式（保留既有 `party`/`message_log`/`gold` 與 `_ready` 不動）：

```gdscript
var current_map_id: String = ""
var player_pos: Vector2i = Vector2i.ZERO
var player_facing: int = GridDirection.Dir.NORTH
var cleared_encounters: Dictionary = {}  # String map_id -> Array[Vector2i]

func mark_encounter_cleared(map_id: String, pos: Vector2i) -> void:
	var list: Array = cleared_encounters.get(map_id, [])
	if not list.has(pos):
		list.append(pos)
	cleared_encounters[map_id] = list

func cleared_for(map_id: String) -> Array:
	return cleared_encounters.get(map_id, [])
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：全部 PASS（含既有測試）。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add location and cleared-encounter state to GameState"
```

---

### Task 2：`MapManager` 設定 `map_id` 與 `load_by_id`

存檔以 id 參照地圖，但目前地圖從寫死路徑載入、`map_id` 為空。讓 `load_text_file` 由檔名設 `map_id`，並新增 `load_by_id` 供讀檔時用 id 載回地圖。

**Files:**
- Modify: `autoload/map_manager.gd`
- Test: `tests/autoload/test_map_manager.gd`（既有檔，**新增** test func）

**Interfaces:**
- Consumes：既有 `load_text(text)` / `_set_current(map)`；`res://content/maps/level01.txt`（既有，含遭遇格 `g`@(2,2)、`o`@(4,4)）。
- Produces：`MapManager` 新常數 `MAPS_DIR := "res://content/maps"`；`load_text_file(path)` 載入後設 `current_map.map_id = <檔名主幹>`；新函式 `load_by_id(id: String) -> MapData`。

- [ ] **Step 1：在 `tests/autoload/test_map_manager.gd` 末尾新增失敗測試**

```gdscript
func test_load_by_id_loads_level01_and_sets_map_id():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.load_by_id("level01")
	assert_not_null(map)
	assert_eq(map.map_id, "level01")
	assert_eq(mm.current_map, map)
	assert_gt(mm.current_grid.width, 0)
	assert_true(mm.current_map.has_encounter(Vector2i(2, 2)), "level01 (2,2) 應有遭遇")
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL（`load_by_id` 未定義）。既有 `test_load_text_sets_current_map_and_grid` 仍 PASS。

- [ ] **Step 3：修改 `autoload/map_manager.gd`**

在 `extends Node` 註解後加常數，並改 `load_text_file`、新增 `load_by_id`（`load_text`/`_set_current` 不動）：

```gdscript
const MAPS_DIR := "res://content/maps"
```

```gdscript
func load_text_file(path: String) -> MapData:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "MapManager.load_text_file: cannot read %s" % path)
	var map := load_text(text)
	map.map_id = path.get_file().get_basename()  # "level01.txt" → "level01"
	return map

func load_by_id(id: String) -> MapData:
	return load_text_file("%s/%s.txt" % [MAPS_DIR, id])
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：全部 PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: assign map_id from filename and add MapManager.load_by_id"
```

---

### Task 3：`SaveData` 快照資料類別

跨層交握的純資料容器。

**Files:**
- Create: `engine/save/save_data.gd`
- Test: `tests/engine/save/test_save_data.gd`

**Interfaces:**
- Consumes：`Party`（既有 class）。
- Produces：`class_name SaveData extends RefCounted`，欄位 `gold: int`、`map_id: String`、`player_pos: Vector2i`、`player_facing: int`、`party: Party`、`cleared_encounters: Dictionary`。

- [ ] **Step 1：寫失敗測試 `tests/engine/save/test_save_data.gd`**

```gdscript
extends GutTest

func test_defaults():
	var d := SaveData.new()
	assert_eq(d.gold, 0)
	assert_eq(d.map_id, "")
	assert_eq(d.player_pos, Vector2i.ZERO)
	assert_eq(d.player_facing, 0)
	assert_null(d.party)
	assert_eq(d.cleared_encounters.size(), 0)

func test_holds_fields():
	var d := SaveData.new()
	d.gold = 120
	d.map_id = "level01"
	d.player_pos = Vector2i(3, 5)
	d.player_facing = 1
	d.party = Party.new()
	d.cleared_encounters = {"level01": [Vector2i(4, 2)]}
	assert_eq(d.gold, 120)
	assert_eq(d.map_id, "level01")
	assert_eq(d.player_pos, Vector2i(3, 5))
	assert_eq(d.player_facing, 1)
	assert_not_null(d.party)
	assert_eq(d.cleared_encounters["level01"].size(), 1)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "SaveData" not declared`（必要時先 `--import`）。

- [ ] **Step 3：寫最小實作 `engine/save/save_data.gd`**

```gdscript
class_name SaveData
extends RefCounted

var gold: int = 0
var map_id: String = ""
var player_pos: Vector2i = Vector2i.ZERO
var player_facing: int = 0
var party: Party = null
var cleared_encounters: Dictionary = {}  # String map_id -> Array[Vector2i]
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add SaveData snapshot struct"
```

---

### Task 4：`SaveSerializer`（to_dict / from_dict 全欄位 roundtrip）

純靜態序列化器：`SaveData` ↔ `Dictionary`。**這是架構文件指名的 TDD roundtrip 目標**。不碰 JSON、不碰檔案、不蓋時間戳（決定性）。

**Files:**
- Create: `engine/save/save_serializer.gd`
- Test: `tests/engine/save/test_save_serializer.gd`

**Interfaces:**
- Consumes：`SaveData`（Task 3）、`Character`/`Party`（既有）。
- Produces：`class_name SaveSerializer extends Object`，`const VERSION := 1`，靜態 `to_dict(data: SaveData) -> Dictionary`、`from_dict(raw: Dictionary) -> SaveData`（版本不符或缺 `state` → 回 `null`）。輸出結構：`{version, meta:{map_id,gold,party:[{name,level}]}, state:{gold,map_id,player_pos:[x,y],player_facing,party:[{完整角色欄位}],cleared_encounters:{map_id:[[x,y]]}}}`。

- [ ] **Step 1：寫失敗測試 `tests/engine/save/test_save_serializer.gd`**

```gdscript
extends GutTest

func _sample() -> SaveData:
	var a := Character.new()
	a.name = "Gerard"; a.char_class = "Knight"; a.level = 3
	a.hp = 28; a.hp_max = 30; a.sp = 0; a.sp_max = 0
	a.might = 15; a.intellect = 12; a.personality = 11; a.endurance = 14
	a.speed = 13; a.accuracy = 13; a.luck = 11
	a.condition = Character.Condition.OK; a.experience = 250
	var b := Character.new()
	b.name = "Marcus"; b.char_class = "Cleric"; b.level = 3
	b.hp = 0; b.hp_max = 22; b.sp = 9; b.sp_max = 14
	b.might = 10; b.intellect = 16; b.personality = 17; b.endurance = 12
	b.speed = 11; b.accuracy = 10; b.luck = 9
	b.condition = Character.Condition.UNCONSCIOUS; b.experience = 240
	var p := Party.new()
	p.members = [a, b]
	var d := SaveData.new()
	d.gold = 120; d.map_id = "level01"
	d.player_pos = Vector2i(3, 5); d.player_facing = GridDirection.Dir.EAST
	d.party = p
	d.cleared_encounters = {"level01": [Vector2i(4, 2), Vector2i(7, 9)], "level02": [Vector2i(1, 1)]}
	return d

func test_roundtrip_preserves_scalars_and_party():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_sample()))
	assert_not_null(back)
	assert_eq(back.gold, 120)
	assert_eq(back.map_id, "level01")
	assert_eq(back.player_pos, Vector2i(3, 5))
	assert_eq(back.player_facing, GridDirection.Dir.EAST)
	assert_eq(back.party.members.size(), 2)
	var a2: Character = back.party.members[0]
	assert_eq(a2.name, "Gerard")
	assert_eq(a2.level, 3)
	assert_eq(a2.hp, 28)
	assert_eq(a2.hp_max, 30)
	assert_eq(a2.might, 15)
	assert_eq(a2.accuracy, 13)
	assert_eq(a2.experience, 250)
	var b2: Character = back.party.members[1]
	assert_eq(b2.name, "Marcus")
	assert_eq(b2.condition, Character.Condition.UNCONSCIOUS)
	assert_eq(b2.sp_max, 14)

func test_roundtrip_cleared_encounters_multi_map():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_sample()))
	assert_eq(back.cleared_encounters.size(), 2)
	var l1: Array = back.cleared_encounters["level01"]
	assert_eq(l1.size(), 2)
	assert_true(l1.has(Vector2i(4, 2)))
	assert_true(l1.has(Vector2i(7, 9)))
	assert_true(back.cleared_encounters["level02"].has(Vector2i(1, 1)))

func test_roundtrip_empty_party():
	var d := SaveData.new()
	d.party = Party.new()
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(d))
	assert_not_null(back)
	assert_eq(back.party.members.size(), 0)

func test_to_dict_has_version_and_meta():
	var raw := SaveSerializer.to_dict(_sample())
	assert_eq(raw["version"], SaveSerializer.VERSION)
	assert_eq(raw["meta"]["map_id"], "level01")
	assert_eq(raw["meta"]["gold"], 120)
	assert_eq(raw["meta"]["party"].size(), 2)
	assert_eq(raw["meta"]["party"][0]["name"], "Gerard")

func test_from_dict_rejects_version_mismatch():
	var raw := SaveSerializer.to_dict(_sample())
	raw["version"] = 999
	assert_null(SaveSerializer.from_dict(raw))

func test_from_dict_rejects_missing_state():
	assert_null(SaveSerializer.from_dict({"version": SaveSerializer.VERSION}))
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "SaveSerializer" not declared`（必要時先 `--import`）。

- [ ] **Step 3：寫實作 `engine/save/save_serializer.gd`**

```gdscript
class_name SaveSerializer
extends Object

const VERSION := 1

static func to_dict(data: SaveData) -> Dictionary:
	return {
		"version": VERSION,
		"meta": _meta(data),
		"state": {
			"gold": data.gold,
			"map_id": data.map_id,
			"player_pos": _vec(data.player_pos),
			"player_facing": data.player_facing,
			"party": _party_to_array(data.party),
			"cleared_encounters": _cleared_to_dict(data.cleared_encounters),
		},
	}

static func from_dict(raw: Dictionary) -> SaveData:
	if int(raw.get("version", -1)) != VERSION:
		return null
	if not raw.has("state"):
		return null
	var s: Dictionary = raw["state"]
	var data := SaveData.new()
	data.gold = int(s.get("gold", 0))
	data.map_id = String(s.get("map_id", ""))
	data.player_pos = _to_vec(s.get("player_pos", [0, 0]))
	data.player_facing = int(s.get("player_facing", 0))
	data.party = _party_from_array(s.get("party", []))
	data.cleared_encounters = _cleared_from_dict(s.get("cleared_encounters", {}))
	return data

# --- internal ---

static func _meta(data: SaveData) -> Dictionary:
	var brief: Array = []
	if data.party != null:
		for m in data.party.members:
			brief.append({"name": m.name, "level": m.level})
	return {"map_id": data.map_id, "gold": data.gold, "party": brief}

static func _vec(v: Vector2i) -> Array:
	return [v.x, v.y]

static func _to_vec(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))

static func _party_to_array(p: Party) -> Array:
	var out: Array = []
	if p == null:
		return out
	for m in p.members:
		out.append(_char_to_dict(m))
	return out

static func _party_from_array(arr) -> Party:
	var p := Party.new()
	var members: Array[Character] = []
	for d in arr:
		members.append(_char_from_dict(d))
	p.members = members
	return p

static func _char_to_dict(c: Character) -> Dictionary:
	return {
		"name": c.name, "char_class": c.char_class, "level": c.level,
		"hp": c.hp, "hp_max": c.hp_max, "sp": c.sp, "sp_max": c.sp_max,
		"might": c.might, "intellect": c.intellect, "personality": c.personality,
		"endurance": c.endurance, "speed": c.speed, "accuracy": c.accuracy,
		"luck": c.luck, "condition": c.condition, "experience": c.experience,
	}

static func _char_from_dict(d: Dictionary) -> Character:
	var c := Character.new()
	c.name = String(d.get("name", ""))
	c.char_class = String(d.get("char_class", ""))
	c.level = int(d.get("level", 1))
	c.hp = int(d.get("hp", 0))
	c.hp_max = int(d.get("hp_max", 0))
	c.sp = int(d.get("sp", 0))
	c.sp_max = int(d.get("sp_max", 0))
	c.might = int(d.get("might", 0))
	c.intellect = int(d.get("intellect", 0))
	c.personality = int(d.get("personality", 0))
	c.endurance = int(d.get("endurance", 0))
	c.speed = int(d.get("speed", 0))
	c.accuracy = int(d.get("accuracy", 0))
	c.luck = int(d.get("luck", 0))
	c.condition = int(d.get("condition", 0))
	c.experience = int(d.get("experience", 0))
	return c

static func _cleared_to_dict(cleared: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id in cleared:
		var arr: Array = []
		for pos in cleared[map_id]:
			arr.append(_vec(pos))
		out[map_id] = arr
	return out

static func _cleared_from_dict(raw) -> Dictionary:
	var out: Dictionary = {}
	for map_id in raw:
		var positions: Array[Vector2i] = []
		for a in raw[map_id]:
			positions.append(_to_vec(a))
		out[String(map_id)] = positions
	return out
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：6 個測試全 PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add SaveSerializer with full SaveData round-trip"
```

---

### Task 5：`SaveSystem` 磁碟層（write_slot / read_slot / has_slot / delete_slot）

建立 autoload 腳本，先做磁碟 IO 與 JSON。測試用 newing 出的實例（不依賴 autoload 註冊；註冊在 Task 8）。`saved_at` 在此蓋章。

**Files:**
- Create: `autoload/save_system.gd`
- Test: `tests/autoload/test_save_system_disk.gd`

**Interfaces:**
- Consumes：`SaveData`（Task 3）、`SaveSerializer`（Task 4）。
- Produces：`SaveSystem` 腳本（`extends Node`，**不給 class_name**），`signal loaded`，`const SAVE_DIR := "user://saves"`、`const SLOT_COUNT := 5`；方法 `_slot_path(slot)`、`has_slot(slot) -> bool`、`delete_slot(slot) -> void`、`write_slot(slot, data: SaveData) -> bool`、`read_slot(slot) -> SaveData`（缺檔／壞檔 → `null`）。

- [ ] **Step 1：寫失敗測試 `tests/autoload/test_save_system_disk.gd`**

```gdscript
extends GutTest

const SaveSystemScript := preload("res://autoload/save_system.gd")
const TEST_SLOT := 3

var _sys

func before_each():
	_sys = SaveSystemScript.new()
	add_child_autofree(_sys)

func after_each():
	_sys.delete_slot(TEST_SLOT)

func _sample() -> SaveData:
	var c := Character.new()
	c.name = "Hero"; c.level = 4; c.hp = 20; c.hp_max = 25; c.experience = 500
	c.condition = Character.Condition.OK
	var p := Party.new()
	p.members = [c]
	var d := SaveData.new()
	d.gold = 77; d.map_id = "level01"
	d.player_pos = Vector2i(2, 6); d.player_facing = 2
	d.party = p
	d.cleared_encounters = {"level01": [Vector2i(5, 5)]}
	return d

func test_write_then_read_roundtrips_through_disk():
	assert_true(_sys.write_slot(TEST_SLOT, _sample()))
	assert_true(_sys.has_slot(TEST_SLOT))
	var back := _sys.read_slot(TEST_SLOT)
	assert_not_null(back)
	assert_eq(back.gold, 77)
	assert_eq(back.map_id, "level01")
	assert_eq(back.player_pos, Vector2i(2, 6))
	assert_eq(back.player_facing, 2)
	assert_eq(back.party.members.size(), 1)
	assert_eq(back.party.members[0].name, "Hero")
	assert_eq(back.party.members[0].experience, 500)
	assert_true(back.cleared_encounters["level01"].has(Vector2i(5, 5)))

func test_read_missing_slot_returns_null():
	_sys.delete_slot(TEST_SLOT)
	assert_false(_sys.has_slot(TEST_SLOT))
	assert_null(_sys.read_slot(TEST_SLOT))

func test_read_corrupt_slot_returns_null():
	DirAccess.make_dir_recursive_absolute(SaveSystemScript.SAVE_DIR)
	var f := FileAccess.open(_sys._slot_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string("{ this is not valid json ")
	f.close()
	assert_null(_sys.read_slot(TEST_SLOT))

func test_delete_slot_removes_file():
	_sys.write_slot(TEST_SLOT, _sample())
	assert_true(_sys.has_slot(TEST_SLOT))
	_sys.delete_slot(TEST_SLOT)
	assert_false(_sys.has_slot(TEST_SLOT))
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL（找不到 `write_slot` 等）。

- [ ] **Step 3：寫實作 `autoload/save_system.gd`**

```gdscript
extends Node
# Autoload 單例 "SaveSystem"：多槽 JSON 存讀檔。
# 故意不給 class_name，避免與 autoload 名稱衝突，比照 GameState/MapManager。

signal loaded

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 5

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]

func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func delete_slot(slot: int) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(_slot_path(slot))

func write_slot(slot: int, data: SaveData) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var raw := SaveSerializer.to_dict(data)
	raw["meta"]["saved_at"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(raw, "  "))
	f.close()
	return true

func read_slot(slot: int) -> SaveData:
	if not has_slot(slot):
		return null
	var text := FileAccess.get_file_as_string(_slot_path(slot))
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	return SaveSerializer.from_dict(raw)
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：4 個測試全 PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add SaveSystem disk layer (write/read/has/delete slot)"
```

---

### Task 6：`SaveSystem.list_slots`（槽位 meta，供選單列表）

不完整反序列化即可取得每槽摘要（含 `saved_at`）。

**Files:**
- Modify: `autoload/save_system.gd`
- Test: `tests/autoload/test_save_system_list.gd`

**Interfaces:**
- Consumes：Task 5 的 `_slot_path`/`has_slot`/`write_slot`、`SLOT_COUNT`。
- Produces：`list_slots() -> Array`（長度 = `SLOT_COUNT`；每格是該槽 `meta` Dictionary，空槽／壞檔 → 空 `{}`）。

- [ ] **Step 1：寫失敗測試 `tests/autoload/test_save_system_list.gd`**

```gdscript
extends GutTest

const SaveSystemScript := preload("res://autoload/save_system.gd")

var _sys

func before_each():
	_sys = SaveSystemScript.new()
	add_child_autofree(_sys)

func after_each():
	for slot in SaveSystemScript.SLOT_COUNT:
		_sys.delete_slot(slot)

func _sample() -> SaveData:
	var c := Character.new()
	c.name = "Hero"; c.level = 4
	var p := Party.new()
	p.members = [c]
	var d := SaveData.new()
	d.gold = 88; d.map_id = "level01"
	d.party = p
	return d

func test_list_slots_reports_occupied_and_empty():
	_sys.write_slot(0, _sample())
	_sys.write_slot(2, _sample())
	var slots := _sys.list_slots()
	assert_eq(slots.size(), SaveSystemScript.SLOT_COUNT)
	assert_false(slots[0].is_empty(), "第 0 槽應有 meta")
	assert_eq(slots[0]["map_id"], "level01")
	assert_eq(int(slots[0]["gold"]), 88)
	assert_true(slots[0].has("saved_at"), "meta 應含 saved_at 時間戳")
	assert_true(slots[1].is_empty(), "第 1 槽應為空")
	assert_false(slots[2].is_empty(), "第 2 槽應有 meta")
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL（`list_slots` 未定義）。

- [ ] **Step 3：在 `autoload/save_system.gd` 新增 `list_slots` 與 `_slot_meta`**

```gdscript
func list_slots() -> Array:
	var out: Array = []
	for slot in SLOT_COUNT:
		out.append(_slot_meta(slot))
	return out

func _slot_meta(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var text := FileAccess.get_file_as_string(_slot_path(slot))
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY or not raw.has("meta"):
		return {}
	return raw["meta"]
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add SaveSystem.list_slots with per-slot meta"
```

---

### Task 7：`SaveSystem` 注入式 `capture_from` / `apply_to`

把 GameState/MapManager ↔ SaveData 的搬運做成「吃實例參數」的函式，便於用 newing 出的實例單元測試（不污染全域 autoload）。

**Files:**
- Modify: `autoload/save_system.gd`
- Test: `tests/autoload/test_save_system_capture_apply.gd`

**Interfaces:**
- Consumes：`GameState` 介面（Task 1 的欄位＋`cleared_for`）、`MapManager.load_by_id`（Task 2）、`SaveData`。
- Produces：`capture_from(gs) -> SaveData`、`apply_to(data: SaveData, gs, mm) -> void`（還原欄位後 `mm.load_by_id(map_id)`，再依 `gs.cleared_for(map_id)` 從新地圖抹除已清遭遇；**不 emit 訊號**，emit 由 Task 8 的公開 `apply` 負責）。

- [ ] **Step 1：寫失敗測試 `tests/autoload/test_save_system_capture_apply.gd`**

```gdscript
extends GutTest

const SaveSystemScript := preload("res://autoload/save_system.gd")
const GameStateScript := preload("res://autoload/game_state.gd")
const MapManagerScript := preload("res://autoload/map_manager.gd")

func _sys() -> Node:
	var s = SaveSystemScript.new()
	add_child_autofree(s)
	return s

func _gs() -> Node:
	var g = GameStateScript.new()
	add_child_autofree(g)
	return g

func _mm() -> Node:
	var m = MapManagerScript.new()
	add_child_autofree(m)
	return m

func test_capture_from_reads_game_state():
	var ss = _sys()
	var gs = _gs()
	gs.gold = 99
	gs.current_map_id = "level01"
	gs.player_pos = Vector2i(4, 7)
	gs.player_facing = GridDirection.Dir.SOUTH
	gs.mark_encounter_cleared("level01", Vector2i(1, 1))
	var data = ss.capture_from(gs)
	assert_eq(data.gold, 99)
	assert_eq(data.map_id, "level01")
	assert_eq(data.player_pos, Vector2i(4, 7))
	assert_eq(data.player_facing, GridDirection.Dir.SOUTH)
	assert_eq(data.party, gs.party)
	assert_true(data.cleared_encounters["level01"].has(Vector2i(1, 1)))

func test_apply_to_restores_state_and_clears_encounters():
	var ss = _sys()
	var gs = _gs()
	var mm = _mm()
	# 先載一次 level01 取得一個真實遭遇格座標
	mm.load_by_id("level01")
	var enc: Vector2i = mm.current_map.encounters.keys()[0]
	var data := SaveData.new()
	data.gold = 50
	data.map_id = "level01"
	data.player_pos = Vector2i(1, 1)
	data.player_facing = GridDirection.Dir.WEST
	data.party = Party.create_default()
	data.cleared_encounters = {"level01": [enc]}
	ss.apply_to(data, gs, mm)
	assert_eq(gs.gold, 50)
	assert_eq(gs.current_map_id, "level01")
	assert_eq(gs.player_pos, Vector2i(1, 1))
	assert_eq(gs.player_facing, GridDirection.Dir.WEST)
	assert_eq(mm.current_map.map_id, "level01")
	assert_false(mm.current_map.has_encounter(enc), "已清遭遇應被抹除")
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL（`capture_from`/`apply_to` 未定義）。

- [ ] **Step 3：在 `autoload/save_system.gd` 新增 `capture_from` / `apply_to`**

```gdscript
func capture_from(gs) -> SaveData:
	var data := SaveData.new()
	data.gold = gs.gold
	data.map_id = gs.current_map_id
	data.player_pos = gs.player_pos
	data.player_facing = gs.player_facing
	data.party = gs.party
	data.cleared_encounters = gs.cleared_encounters
	return data

func apply_to(data: SaveData, gs, mm) -> void:
	gs.party = data.party
	gs.gold = data.gold
	gs.current_map_id = data.map_id
	gs.player_pos = data.player_pos
	gs.player_facing = data.player_facing
	gs.cleared_encounters = data.cleared_encounters
	mm.load_by_id(data.map_id)
	for pos in gs.cleared_for(data.map_id):
		mm.current_map.clear_encounter(pos)
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：2 個測試 PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add SaveSystem capture_from/apply_to (injectable)"
```

---

### Task 8：`SaveSystem` 公開包裝 + autoload 註冊

薄的全域包裝（用 `GameState`/`MapManager` 單例）＋註冊 autoload，讓遊戲可呼叫。整合測試用真實 autoload。

**Files:**
- Modify: `autoload/save_system.gd`
- Modify: `project.godot`（`[autoload]` 區）
- Test: `tests/autoload/test_save_system_integration.gd`

**Interfaces:**
- Consumes：Task 5–7 的 `write_slot`/`read_slot`/`capture_from`/`apply_to`、全域 `GameState`/`MapManager`。
- Produces：`capture() -> SaveData`、`apply(data: SaveData) -> void`（呼叫 `apply_to` 後 `loaded.emit()`）、`save_to_slot(slot) -> bool`、`load_from_slot(slot) -> bool`；`SaveSystem` 註冊為 autoload。

- [ ] **Step 1：寫失敗測試 `tests/autoload/test_save_system_integration.gd`**

```gdscript
extends GutTest

const TEST_SLOT := 0

func after_each():
	SaveSystem.delete_slot(TEST_SLOT)

func test_save_then_load_restores_global_state_and_emits_loaded():
	GameState.gold = 321
	GameState.current_map_id = "level01"
	GameState.player_pos = Vector2i(2, 1)
	GameState.player_facing = GridDirection.Dir.EAST
	GameState.cleared_encounters = {}
	assert_true(SaveSystem.save_to_slot(TEST_SLOT))
	# 竄改現況，確認讀檔會覆蓋回去
	GameState.gold = 0
	GameState.player_pos = Vector2i.ZERO
	watch_signals(SaveSystem)
	assert_true(SaveSystem.load_from_slot(TEST_SLOT))
	assert_eq(GameState.gold, 321)
	assert_eq(GameState.player_pos, Vector2i(2, 1))
	assert_eq(GameState.current_map_id, "level01")
	assert_signal_emitted(SaveSystem, "loaded")

func test_load_missing_slot_returns_false():
	SaveSystem.delete_slot(TEST_SLOT)
	assert_false(SaveSystem.load_from_slot(TEST_SLOT))
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL（`SaveSystem` autoload 尚未註冊／`save_to_slot` 未定義）。

- [ ] **Step 3：在 `autoload/save_system.gd` 新增公開包裝**

```gdscript
func capture() -> SaveData:
	return capture_from(GameState)

func apply(data: SaveData) -> void:
	apply_to(data, GameState, MapManager)
	loaded.emit()

func save_to_slot(slot: int) -> bool:
	return write_slot(slot, capture())

func load_from_slot(slot: int) -> bool:
	var data := read_slot(slot)
	if data == null:
		return false
	apply(data)
	return true
```

- [ ] **Step 4：在 `project.godot` 的 `[autoload]` 末尾註冊 SaveSystem**

把該區改成（**新增最後一行**，順序在 `GameState` 之後，因為包裝會用到 `GameState`/`MapManager`）：

```
[autoload]

MapManager="*res://autoload/map_manager.gd"
GameState="*res://autoload/game_state.gd"
SaveSystem="*res://autoload/save_system.gd"
```

- [ ] **Step 5：跑測試確認全綠**

Run（測試指令）。Expected：2 個整合測試 PASS（全測試全綠）。

- [ ] **Step 6：commit**

```bash
git add -A && git commit -m "feat: add SaveSystem public API and register autoload"
```

---

### Task 9：`main.gd` 座標同步進 GameState + 勝利記錄已清遭遇

讓執行期的玩家座標／面向／地圖 id 持續寫回 `GameState`（存檔才抓得到正確進度），並在戰鬥勝利時記錄已清遭遇。本任務為呈現層接線，**手動驗證**（座標同步的正確性會在 Task 10 端到端驗證）。

**Files:**
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes：既有 `_player.entered_cell`/`facing_changed` 訊號、`MapManager.load_text_file`（現會設 `map_id`）、`GameState`（Task 1 欄位＋`mark_encounter_cleared`）。
- Produces：`main.gd` 在 `_ready` 連 `facing_changed`、設初始 `GameState` 座標；`_on_entered_cell` 內同步 `player_pos`；新 `_on_facing_changed`；`_on_combat_finished` VICTORY 分支記錄已清遭遇。

- [ ] **Step 1：在 `_ready()` 中加入座標同步接線**

在 `_player.entered_cell.connect(_on_entered_cell)` 之後加一行連接面向訊號：

```gdscript
	_player.facing_changed.connect(_on_facing_changed)
```

並在 `_ready()` 末尾（既有 `_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)` 之後）加入初始同步：

```gdscript
	GameState.current_map_id = map.map_id
	GameState.player_pos = map.start_pos
	GameState.player_facing = map.start_facing
```

- [ ] **Step 2：在 `_on_entered_cell` 開頭同步 `player_pos`，並新增 `_on_facing_changed`**

把 `_on_entered_cell` 改成（**首行新增** `GameState.player_pos = pos`，其餘不動）：

```gdscript
func _on_entered_cell(pos: Vector2i) -> void:
	GameState.player_pos = pos
	if MapManager.current_map.has_encounter(pos):
		_start_combat(pos)
		return
	var text := TileMessages.for_tile(MapManager.current_map.get_tile(pos))
	if text != "":
		GameState.message_log.push(text)
```

新增面向同步 handler（放在 `_on_entered_cell` 後）：

```gdscript
func _on_facing_changed(facing: int) -> void:
	GameState.player_facing = facing
```

- [ ] **Step 3：在 `_on_combat_finished` 的 VICTORY 分支記錄已清遭遇**

把 VICTORY 分支改成（**新增** `mark_encounter_cleared` 一行，緊接既有 `clear_encounter` 之後）：

```gdscript
	if result == CombatSystem.Result.VICTORY:
		_grant_rewards()
		MapManager.current_map.clear_encounter(_combat_pos)
		GameState.mark_encounter_cleared(MapManager.current_map.map_id, _combat_pos)
		GameState.message_log.push("戰鬥勝利！")
		_player.set_enabled(true)
```

- [ ] **Step 4：手動驗證（回歸檢查）**

跑遊戲：

```bash
godot --path .
```

確認：(a) 能正常前進／後退／平移／轉向；(b) 走到哥布林格（從起點 `@`(1,1) 往南到 (1,2) 再往東到 (2,2)）會觸發戰鬥；(c) 戰鬥可攻擊／勝利、金幣增加、HUD 正常刷新。**與 Task 9 前行為一致即通過**（GameState 同步無法在此直接觀察，於 Task 10 端到端驗證）。先跑一次全測試確認無回歸：

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：全測試 PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: sync player location into GameState and record cleared encounters"
```

---

### Task 10：`SaveMenu` 存讀檔選單 + main.gd 接線（Tab 開關 + loaded 重建世界）

程式建構的存讀檔選單（無真美術），鍵盤操作；`main.gd` 以 Tab 開關選單、戰鬥中禁用、接 `SaveSystem.loaded` 重建世界。**手動驗證**，比照 M4 的 `CombatLayer`。

**Files:**
- Create: `presentation/ui/save_menu.gd`
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes：全域 `SaveSystem`（`list_slots`/`save_to_slot`/`load_from_slot`/`has_slot`/`delete_slot`/`SLOT_COUNT`/`loaded`）、`GameState.message_log`、`MapManager.current_map`/`current_grid`、`_world_builder.build`、`_player.setup`/`set_enabled`、`_hud.refresh`。
- Produces：`class_name SaveMenu extends CanvasLayer`（`open()`/`close()`/`is_open()`、`signal closed`）；`main.gd` 持有 `_save_menu`、`_unhandled_input` 切換、`_on_menu_closed`、`_on_loaded`。

- [ ] **Step 1：建立 `presentation/ui/save_menu.gd`**

```gdscript
class_name SaveMenu
extends CanvasLayer

# 程式建構的存讀檔選單（無真美術）：列出 SLOT_COUNT 槽，鍵盤操作。
# [↑/↓ 或 1-5] 選槽 / [S] 存檔 / [L] 讀檔 / [X] 刪除（需 Y 確認）/ [Esc] 關閉
# 直接驅動 SaveSystem；讀檔成功後關閉，世界重建由 main 接 SaveSystem.loaded。
# 不呼叫 set_input_as_handled：開啟期間 main 只看 Tab、player 已被停用，無按鍵衝突。

signal closed

var _panel: Label
var _selected := 0
var _confirm_delete := false

func is_open() -> bool:
	return visible

func open() -> void:
	visible = true
	_selected = 0
	_confirm_delete = false
	set_process_unhandled_input(true)
	_refresh()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	closed.emit()

func _ready() -> void:
	layer = 10
	visible = false
	_panel = Label.new()
	_panel.position = Vector2(60, 60)
	_panel.add_theme_font_size_override("font_size", 18)
	add_child(_panel)
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	if _confirm_delete:
		if key == KEY_Y:
			SaveSystem.delete_slot(_selected)
		_confirm_delete = false
		_refresh()
		return
	if key == KEY_ESCAPE:
		close()
	elif key == KEY_UP:
		_selected = (_selected + SaveSystem.SLOT_COUNT - 1) % SaveSystem.SLOT_COUNT
		_refresh()
	elif key == KEY_DOWN:
		_selected = (_selected + 1) % SaveSystem.SLOT_COUNT
		_refresh()
	elif key >= KEY_1 and key <= KEY_5:
		var idx := key - KEY_1
		if idx < SaveSystem.SLOT_COUNT:
			_selected = idx
			_refresh()
	elif key == KEY_S:
		SaveSystem.save_to_slot(_selected)
		GameState.message_log.push("已存檔到第 %d 槽。" % (_selected + 1))
		_refresh()
	elif key == KEY_L:
		if SaveSystem.has_slot(_selected):
			SaveSystem.load_from_slot(_selected)
			GameState.message_log.push("已讀取第 %d 槽。" % (_selected + 1))
			close()
	elif key == KEY_X:
		if SaveSystem.has_slot(_selected):
			_confirm_delete = true
			_refresh()

func _refresh() -> void:
	var lines: Array[String] = ["== 存讀檔 ==  [↑↓/1-5]選 [S]存 [L]讀 [X]刪 [Esc]關"]
	var slots := SaveSystem.list_slots()
	for i in slots.size():
		var marker := "> " if i == _selected else "  "
		var meta: Dictionary = slots[i]
		var desc := "（空）"
		if not meta.is_empty():
			desc = "%s  金幣%d  %s" % [
				meta.get("map_id", "?"), int(meta.get("gold", 0)), meta.get("saved_at", "")]
		lines.append("%s第%d槽：%s" % [marker, i + 1, desc])
	if _confirm_delete:
		lines.append("確認刪除第 %d 槽？[Y] 確認 / 其他鍵取消" % (_selected + 1))
	_panel.text = "\n".join(lines)
```

- [ ] **Step 2：在 `main.gd` 加 `_save_menu` 欄位並於 `_ready` 建立、接線**

在 `var _combat_pos: Vector2i` 之後新增欄位：

```gdscript
var _save_menu: SaveMenu
```

在 `_ready()` 中、`_combat_layer.combat_finished.connect(_on_combat_finished)` 之後加入：

```gdscript
	_save_menu = SaveMenu.new()
	add_child(_save_menu)
	_save_menu.closed.connect(_on_menu_closed)
	SaveSystem.loaded.connect(_on_loaded)
```

- [ ] **Step 3：在 `main.gd` 新增選單開關與 loaded 重建 handler**

在檔案末尾（`_show_game_over` 之後）新增：

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_TAB:
		return
	if _combat != null:
		return  # 戰鬥中禁用選單
	if _save_menu.is_open():
		_save_menu.close()
	else:
		_player.set_enabled(false)
		_save_menu.open()

func _on_menu_closed() -> void:
	_player.set_enabled(true)

func _on_loaded() -> void:
	_world_builder.build(MapManager.current_map)
	_player.setup(MapManager.current_grid, GameState.player_pos, GameState.player_facing)
	_hud.refresh()
	GameState.message_log.push("讀檔完成。")
```

- [ ] **Step 4：手動驗證（端到端，含 Task 9 的座標同步與已清遭遇持久化）**

跑遊戲：

```bash
godot --path .
```

依序確認：
1. 按 **Tab** → 出現選單，5 槽皆「（空）」。
2. 選第 1 槽按 **S** → 該槽顯示 `level01 金幣0 <時間>`，訊息列「已存檔到第 1 槽」。
3. 按 **Tab** 關閉；走到哥布林格（南到 (1,2)、東到 (2,2)）打贏 → 金幣增加，怪物格清空。
4. 再 **Tab → S** 覆寫第 1 槽（此時 meta 金幣 > 0，且存檔含已清遭遇 (2,2)）。
5. **Tab**，移動到別處，**Tab → 選第 1 槽 → L** → 世界重建、玩家回到存檔座標、HUD 還原；訊息列「讀檔完成」。再走回 (2,2) **不應**再觸發哥布林戰鬥（已清遭遇持久化成功）。
6. **完全關掉遊戲再重開** → **Tab** → 第 1 槽仍顯示先前 meta（跨行程持久化）→ **L** 可正常讀回。
7. 選一個有存檔的槽 → **X** → 出現確認 → **Y** → 該槽變「（空）」。
8. 戰鬥中按 **Tab** 不開選單。

每項通過即可。再跑一次全測試確認無回歸：

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：全測試 PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add save/load menu UI wired to SaveSystem (M5a complete)"
```

---

## 完成定義（M5a）

- `SaveData`/`SaveSerializer` 純邏輯、roundtrip 全綠（含 KO 成員、多地圖已清遭遇、版本守門）。
- `SaveSystem` autoload：5 槽 JSON 於 `user://saves/`，磁碟 roundtrip／缺檔／壞檔／刪除／列表皆測過；`capture_from`/`apply_to` 注入式測過；公開 `save_to_slot`/`load_from_slot` 整合測過並 emit `loaded`。
- 玩家座標／面向／地圖 id／已清遭遇住在 `GameState`，由 `main.gd` 同步。
- 存讀檔選單可存／讀／刪 5 槽，讀檔重建世界、還原隊伍／金錢／座標／已清遭遇，且跨行程持久化。
- 既有 M1–M4 測試與行為全數保持綠燈。

## 非目標（M5a 不做，留待 M5b/M5c）

道具／裝備持久化（M5b 擴充 schema）、法術狀態（M5c）、自動存檔、雲端存檔、存檔加密、地圖間轉移（樓梯仍只是可走格）。
