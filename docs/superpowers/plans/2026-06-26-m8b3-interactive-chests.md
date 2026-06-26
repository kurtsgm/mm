# M8b-3 互動寶箱 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 玩家踩上寶箱格自動跳 Y/N 確認，開箱發放 gold + 道具、一次性持久化；同格怪物優先（先戰鬥，勝利後自動補跳開箱）；寶箱開/關兩態視覺。

**Architecture:** 沿用三層分離。資料層在 `MapData` 加通用 `objects` 陣列（本期只 `chest` 型別）；引擎層做純函式 `ChestLoot.grant` 與 `GameState.opened_objects` 持久化（鏡射既有 `cleared_encounters`）；呈現層新增獨立狀態感知的 `ChestLayer`，接進 M10 的 `WorldStitchRenderer` 拼裝路徑（鄰圖也可見、無 pop-in），開箱當下用 `refresh_objects` 只重建目前區的寶箱層。Y/N 用程式建構的 `ChestPrompt`（鏡射既有選單）。

**Tech Stack:** Godot 4.7 / GDScript / GUT 9.7.0（headless 測試）。

## Global Constraints

- 引擎層（`engine/`）純 GDScript 邏輯，不直接依賴 Godot 視覺節點；`autoload` 可依賴。
- 新資料/狀態預設為空，**既有 333 測試不得回歸**（`objects` 預設 `[]`、`opened_objects` 預設 `{}`）。
- 存檔 **VERSION 維持 4**，只「追加」`opened_objects` 欄位；`from_dict` 對缺欄位用 `.get(..., {})` 回退（向後相容 v1/2/3/4）。
- 對使用者顯示的訊息一律繁體中文（沿用既有 `message_log` 風格）。
- 寶箱模型先用**程序化 placeholder `.tscn`**（鏡射 `town_oak_ext` 的「`.tscn` + `.gd` 自建幾何」作法），不阻塞於下載素材；日後可替換 `.tscn` 內容為真模型。
- 測試指令（全套）：`godot --headless -s addons/gut/gut_cmdln.gd -gexit`
- 單檔測試：`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<path>.gd -gexit`
- 主鍵/UUID 規範不適用（本專案為單機遊戲，無資料庫）。

---

## File Structure

**Create:**
- `engine/world/chest_loot.gd` — 純函式：開箱發放（道具進背包、回傳 gold + item ids）。
- `presentation/world/chest_catalog.gd` — style id → {closed, open} 場景路徑對照。
- `presentation/world/chest_layer.gd` — 狀態感知寶箱渲染層（依 opened 選 closed/open 場景）。
- `presentation/ui/chest_prompt.gd` — Y/N 確認覆蓋層（鏡射選單）。
- `content/models/chest/chest.gd` — 程序化寶箱幾何（`@export var opened` 控制開蓋）。
- `content/models/chest/chest_closed.tscn` / `chest_open.tscn` — 兩態 placeholder 場景。
- 測試：`tests/engine/world/test_chest_loot.gd`、`tests/presentation/test_chest_catalog.gd`、`tests/presentation/test_chest_layer.gd`、`tests/presentation/test_chest_prompt.gd`、`tests/autoload/test_game_state_objects.gd`。

**Modify:**
- `resources/map_data.gd` — 加 `objects` 欄與 `has_object`/`get_object`。
- `engine/map/map_importer.gd` — `_parse_entities` 加 `chest` 分支、回傳 `objects`。
- `autoload/game_state.gd` — 加 `opened_objects` 與 mark/is/opened_for。
- `engine/save/save_data.gd` — 加 `opened_objects` 欄。
- `engine/save/save_serializer.gd` — to/from dict 帶 `opened_objects` + `_opened_to_dict`/`_opened_from_dict`。
- `autoload/save_system.gd` — `capture_from`/`apply_to` 帶 `opened_objects`。
- `presentation/world/world_stitch_renderer.gd` — `_build_content` 加 `ChestLayer`、加 `refresh_objects` + `opened_provider`/`_opened_set`。
- `presentation/world/main.gd` — 接線觸發鏈、Y/N 處理、戰後補跳。
- `content/maps/town_oak.json` — 加 demo 寶箱（普通 + 看守）。
- 既有測試擴充：`tests/engine/map/test_map_importer.gd`、`tests/engine/save/test_save_serializer.gd`、`tests/autoload/test_save_system_capture_apply.gd`、`tests/presentation/test_world_stitch_renderer.gd`、`tests/content/test_world_maps.gd`。

---

## Task 1: 資料模型 — MapData.objects + importer 解析 chest

**Files:**
- Modify: `resources/map_data.gd:18` (在 `decorations` 後加 `objects` 與查詢函式)
- Modify: `engine/map/map_importer.gd:80-119` (`_parse_entities` 加 chest 分支)
- Modify: `engine/map/map_importer.gd:40-43` (`parse()` 寫入 `map.objects`)
- Test: `tests/engine/map/test_map_importer.gd`

**Interfaces:**
- Produces: `MapData.objects: Array`（元素 `{pos:Vector2i, items:Array, gold:int, model:String}`）、`MapData.has_object(pos:Vector2i)->bool`、`MapData.get_object(pos:Vector2i)->Dictionary`（找不到回 `{}`）。

- [ ] **Step 1: Write the failing tests** — append to `tests/engine/map/test_map_importer.gd`

```gdscript
func test_chest_entity_parsed_into_objects():
	var json := '{"grid":["@."],"entities":[{"type":"chest","pos":[1,0],"items":["potion","short_sword"],"gold":50}]}'
	var m := MapImporter.parse(json)
	assert_not_null(m)
	assert_eq(m.objects.size(), 1)
	var o: Dictionary = m.objects[0]
	assert_eq(o["pos"], Vector2i(1, 0))
	assert_eq(o["items"], ["potion", "short_sword"])
	assert_eq(o["gold"], 50)
	assert_eq(o["model"], "chest")

func test_chest_defaults_when_fields_omitted():
	var json := '{"grid":["@."],"entities":[{"type":"chest","pos":[1,0]}]}'
	var m := MapImporter.parse(json)
	assert_not_null(m)
	var o: Dictionary = m.objects[0]
	assert_eq(o["items"], [])
	assert_eq(o["gold"], 0)
	assert_eq(o["model"], "chest")

func test_chest_negative_gold_rejected():
	var json := '{"grid":["@."],"entities":[{"type":"chest","pos":[1,0],"gold":-5}]}'
	assert_null(MapImporter.parse(json))

func test_chest_non_numeric_gold_rejected():
	var json := '{"grid":["@."],"entities":[{"type":"chest","pos":[1,0],"gold":"lots"}]}'
	assert_null(MapImporter.parse(json))

func test_chest_out_of_bounds_rejected():
	var json := '{"grid":["@."],"entities":[{"type":"chest","pos":[5,0]}]}'
	assert_null(MapImporter.parse(json))

func test_no_objects_means_empty_array():
	var json := '{"grid":["@."]}'
	var m := MapImporter.parse(json)
	assert_not_null(m)
	assert_eq(m.objects, [])

func test_map_data_has_and_get_object():
	var json := '{"grid":["@."],"entities":[{"type":"chest","pos":[1,0],"gold":10}]}'
	var m := MapImporter.parse(json)
	assert_true(m.has_object(Vector2i(1, 0)))
	assert_false(m.has_object(Vector2i(0, 0)))
	assert_eq(m.get_object(Vector2i(1, 0))["gold"], 10)
	assert_eq(m.get_object(Vector2i(0, 0)), {})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/map/test_map_importer.gd -gexit`
Expected: FAIL（`m.objects` 不存在 / chest 型別走到 `_:` 回 null）

- [ ] **Step 3: Add `objects` field + queries to `resources/map_data.gd`**

在 `@export var decorations: Array = [] ...`（第 18 行）之後新增：

```gdscript
@export var objects: Array = []            # [{ pos:Vector2i, items:Array, gold:int, model:String }]
```

在檔案末端（`get_link` 之後）新增：

```gdscript
func has_object(pos: Vector2i) -> bool:
	for o in objects:
		if o["pos"] == pos:
			return true
	return false

func get_object(pos: Vector2i) -> Dictionary:
	for o in objects:
		if o["pos"] == pos:
			return o
	return {}
```

- [ ] **Step 4: Add chest branch to `engine/map/map_importer.gd`**

在 `_parse_entities`（第 80 行）開頭，`var decorations := []` 後新增：

```gdscript
	var objects := []
```

在 `match` 的 `"decoration":` 分支之後、`_:` 之前新增：

```gdscript
			"chest":
				var items: Array = []
				if e.has("items"):
					if typeof(e["items"]) != TYPE_ARRAY:
						return null
					for it in e["items"]:
						items.append(String(it))
				var gold := 0
				if e.has("gold"):
					if not _is_num(e["gold"]) or int(e["gold"]) < 0:
						return null
					gold = int(e["gold"])
				var model := "chest"
				if e.has("model"):
					model = String(e["model"])
				objects.append({"pos": pos, "items": items, "gold": gold, "model": model})
```

把 `_parse_entities` 結尾的回傳改為：

```gdscript
	return {"encounters": encounters, "links": links, "decorations": decorations, "objects": objects}
```

在 `parse()` 的 `map.decorations = entities["decorations"]`（第 42 行）之後新增：

```gdscript
	map.objects = entities["objects"]
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/map/test_map_importer.gd -gexit`
Expected: PASS（全部）

- [ ] **Step 6: Commit**

```bash
git add resources/map_data.gd engine/map/map_importer.gd tests/engine/map/test_map_importer.gd
git commit -m "feat(map): chest entity → MapData.objects（items/gold/model 解析 + 查詢）"
```

---

## Task 2: 狀態 — GameState.opened_objects

**Files:**
- Modify: `autoload/game_state.gd:13-14` (在 `explored` 旁加 `opened_objects`)
- Modify: `autoload/game_state.gd` (加 mark/is/opened_for，鏡射 `mark_encounter_cleared`/`cleared_for`)
- Test: `tests/autoload/test_game_state_objects.gd` (create)

**Interfaces:**
- Produces: `GameState.opened_objects: Dictionary`（map_id → `Array[Vector2i]`）、`mark_object_opened(map_id:String, pos:Vector2i)`、`is_object_opened(map_id:String, pos:Vector2i)->bool`、`opened_for(map_id:String)->Array`。

- [ ] **Step 1: Write the failing test** — create `tests/autoload/test_game_state_objects.gd`

```gdscript
extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

func _gs() -> Node:
	var gs = GameStateScript.new()
	add_child_autofree(gs)
	return gs

func test_mark_and_query_opened():
	var gs = _gs()
	assert_false(gs.is_object_opened("town_oak", Vector2i(1, 1)))
	gs.mark_object_opened("town_oak", Vector2i(1, 1))
	assert_true(gs.is_object_opened("town_oak", Vector2i(1, 1)))

func test_opened_is_per_map():
	var gs = _gs()
	gs.mark_object_opened("town_oak", Vector2i(1, 1))
	assert_false(gs.is_object_opened("level01", Vector2i(1, 1)))

func test_mark_is_idempotent():
	var gs = _gs()
	gs.mark_object_opened("town_oak", Vector2i(1, 1))
	gs.mark_object_opened("town_oak", Vector2i(1, 1))
	assert_eq(gs.opened_for("town_oak").size(), 1)

func test_opened_for_unknown_map_empty():
	var gs = _gs()
	assert_eq(gs.opened_for("nope"), [])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/autoload/test_game_state_objects.gd -gexit`
Expected: FAIL（`mark_object_opened` 不存在）

- [ ] **Step 3: Implement in `autoload/game_state.gd`**

在 `var explored: Dictionary = {} ...`（第 14 行）之後新增：

```gdscript
var opened_objects: Dictionary = {}  # String map_id -> Array[Vector2i]
```

在 `cleared_for`（第 33 行）之後新增：

```gdscript
func mark_object_opened(map_id: String, pos: Vector2i) -> void:
	var list: Array = opened_objects.get(map_id, [])
	if not list.has(pos):
		list.append(pos)
	opened_objects[map_id] = list

func is_object_opened(map_id: String, pos: Vector2i) -> bool:
	return opened_objects.get(map_id, []).has(pos)

func opened_for(map_id: String) -> Array:
	return opened_objects.get(map_id, [])
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/autoload/test_game_state_objects.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add autoload/game_state.gd tests/autoload/test_game_state_objects.gd
git commit -m "feat(state): GameState.opened_objects 一次性寶箱持久化狀態（per-map 座標集合）"
```

---

## Task 3: 存檔 — opened_objects round-trip + capture/apply

**Files:**
- Modify: `engine/save/save_data.gd:11` (加欄位)
- Modify: `engine/save/save_serializer.gd:10-19` (to_dict state)、`:42` (from_dict)、加 `_opened_to_dict`/`_opened_from_dict`
- Modify: `autoload/save_system.gd:58-78` (`capture_from`/`apply_to`)
- Test: `tests/engine/save/test_save_serializer.gd`、`tests/autoload/test_save_system_capture_apply.gd`

**Interfaces:**
- Consumes: `GameState.opened_objects`（Task 2）。
- Produces: `SaveData.opened_objects: Dictionary`；序列化鍵 `state.opened_objects`（map_id → `Array[[x,y]]`）。

- [ ] **Step 1: Write the failing tests** — append to `tests/engine/save/test_save_serializer.gd`

```gdscript
func test_opened_objects_round_trip():
	var d := SaveData.new()
	d.opened_objects = {"town_oak": [Vector2i(1, 1), Vector2i(3, 1)]}
	var raw := SaveSerializer.to_dict(d)
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.opened_objects, {"town_oak": [Vector2i(1, 1), Vector2i(3, 1)]})

func test_opened_objects_absent_is_empty():
	# 舊檔（無此欄）→ 空字典，不報錯（向後相容）
	var raw := {"version": 4, "state": {"player_pos": [0, 0]}}
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back)
	assert_eq(back.opened_objects, {})
```

並 append to `tests/autoload/test_save_system_capture_apply.gd`：

```gdscript
func test_capture_apply_carries_opened_objects():
	var gs := GameStateScript.new()
	add_child_autofree(gs)
	gs.opened_objects = {"town_oak": [Vector2i(1, 1)]}
	var data := SaveSystem.capture_from(gs)
	assert_eq(data.opened_objects, {"town_oak": [Vector2i(1, 1)]})
	var gs2 := GameStateScript.new()
	add_child_autofree(gs2)
	SaveSystem.apply_to(data, gs2, MapManager)
	assert_eq(gs2.opened_objects, {"town_oak": [Vector2i(1, 1)]})
```

> 註：`test_save_system_capture_apply.gd` 既有檔頭已有 `const GameStateScript := preload(...)`。若無，於檔頭加 `const GameStateScript := preload("res://autoload/game_state.gd")`。

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/save/test_save_serializer.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/autoload/test_save_system_capture_apply.gd -gexit`
Expected: FAIL（`SaveData.opened_objects` 不存在 / 序列化未帶）

- [ ] **Step 3: Add field to `engine/save/save_data.gd`**

在 `var explored: Dictionary = {} ...`（第 11 行）之後新增：

```gdscript
var opened_objects: Dictionary = {}  # String map_id -> Array[Vector2i]
```

- [ ] **Step 4: Serialize in `engine/save/save_serializer.gd`**

`to_dict` 的 `state` 字典在 `"explored": _explored_to_dict(data.explored),`（第 18 行）之後加一行：

```gdscript
				"opened_objects": _opened_to_dict(data.opened_objects),
```

`from_dict` 在 `data.explored = _explored_from_dict(s.get("explored", {}))`（第 42 行）之後加一行：

```gdscript
	data.opened_objects = _opened_from_dict(s.get("opened_objects", {}))
```

在 `_explored_from_dict` 之後（檔案末端）新增（鏡射 `_cleared_*`，內層為 `Array[Vector2i]`）：

```gdscript
static func _opened_to_dict(opened: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id in opened:
		var arr: Array = []
		for pos in opened[map_id]:
			arr.append(_vec(pos))
		out[map_id] = arr
	return out

static func _opened_from_dict(raw) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for map_id in raw:
		var positions: Array[Vector2i] = []
		for a in raw[map_id]:
			if _is_vec_shape(a):
				positions.append(_to_vec(a))
		out[String(map_id)] = positions
	return out
```

- [ ] **Step 5: Carry in `autoload/save_system.gd`**

`capture_from` 在 `data.explored = gs.explored`（第 67 行）之後加：

```gdscript
	data.opened_objects = gs.opened_objects
```

`apply_to` 在 `gs.explored = data.explored`（第 78 行）之後加：

```gdscript
	gs.opened_objects = data.opened_objects
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/save/test_save_serializer.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/autoload/test_save_system_capture_apply.gd -gexit`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add engine/save/save_data.gd engine/save/save_serializer.gd autoload/save_system.gd tests/engine/save/test_save_serializer.gd tests/autoload/test_save_system_capture_apply.gd
git commit -m "feat(save): 序列化 opened_objects（v4 追加欄、向後相容缺欄→空）"
```

---

## Task 4: 引擎邏輯 — ChestLoot.grant 純函式

**Files:**
- Create: `engine/world/chest_loot.gd`
- Test: `tests/engine/world/test_chest_loot.gd`

**Interfaces:**
- Consumes: `Inventory.add(id:String, count:int)`（既有）。
- Produces: `ChestLoot.grant(chest:Dictionary, inventory:Inventory) -> Dictionary`，回 `{"gold": int, "items": Array[String]}`（items = 實際發出的 id 清單）。

- [ ] **Step 1: Write the failing test** — create `tests/engine/world/test_chest_loot.gd`

```gdscript
extends GutTest

func test_grant_adds_items_and_returns_gold():
	var inv := Inventory.new()
	var chest := {"pos": Vector2i(1, 1), "items": ["potion", "short_sword"], "gold": 50, "model": "chest"}
	var res := ChestLoot.grant(chest, inv)
	assert_eq(res["gold"], 50)
	assert_eq(res["items"], ["potion", "short_sword"])
	assert_eq(inv.count_of("potion"), 1)
	assert_eq(inv.count_of("short_sword"), 1)

func test_grant_empty_chest():
	var inv := Inventory.new()
	var chest := {"pos": Vector2i(1, 1), "items": [], "gold": 0, "model": "chest"}
	var res := ChestLoot.grant(chest, inv)
	assert_eq(res["gold"], 0)
	assert_eq(res["items"], [])
	assert_true(inv.is_empty())

func test_grant_skips_empty_id():
	var inv := Inventory.new()
	var chest := {"pos": Vector2i(1, 1), "items": ["", "potion"], "gold": 0, "model": "chest"}
	var res := ChestLoot.grant(chest, inv)
	assert_eq(res["items"], ["potion"])
	assert_eq(inv.count_of("potion"), 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/world/test_chest_loot.gd -gexit`
Expected: FAIL（`ChestLoot` 未定義）

- [ ] **Step 3: Implement `engine/world/chest_loot.gd`**

```gdscript
class_name ChestLoot
extends Object

# 純函式：把寶箱道具加進背包、回傳 gold 與實際發出的 item id 清單。
# 不碰 GameState、不發訊息（金幣加總與訊息由 main 端負責），保持可測。
static func grant(chest: Dictionary, inventory: Inventory) -> Dictionary:
	var granted: Array[String] = []
	var items = chest.get("items", [])
	if items is Array:
		for id in items:
			var sid := String(id)
			if sid == "":
				continue
			inventory.add(sid, 1)
			granted.append(sid)
	return {"gold": int(chest.get("gold", 0)), "items": granted}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/world/test_chest_loot.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add engine/world/chest_loot.gd tests/engine/world/test_chest_loot.gd
git commit -m "feat(world): ChestLoot.grant 純函式（道具進背包 + 回 gold/items）"
```

---

## Task 5: 寶箱素材 placeholder + ChestCatalog

**Files:**
- Create: `content/models/chest/chest.gd`
- Create: `content/models/chest/chest_closed.tscn`
- Create: `content/models/chest/chest_open.tscn`
- Create: `presentation/world/chest_catalog.gd`
- Test: `tests/presentation/test_chest_catalog.gd`

**Interfaces:**
- Produces: `ChestCatalog.has_style(id:String)->bool`、`ChestCatalog.get_scene(id:String, opened:bool)->PackedScene`（未知 id → null）。場景 root 為 `Node3D`。

- [ ] **Step 1: Write the failing test** — create `tests/presentation/test_chest_catalog.gd`

```gdscript
extends GutTest

func test_unknown_style_false_and_null():
	assert_false(ChestCatalog.has_style("nope"))
	assert_null(ChestCatalog.get_scene("nope", false))

func test_registered_chest_loads_both_states():
	assert_true(ChestCatalog.has_style("chest"))
	var closed := ChestCatalog.get_scene("chest", false)
	var opened := ChestCatalog.get_scene("chest", true)
	assert_not_null(closed)
	assert_not_null(opened)

func test_states_are_distinct_scenes():
	assert_ne(ChestCatalog.get_scene("chest", false).resource_path,
		ChestCatalog.get_scene("chest", true).resource_path)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_chest_catalog.gd -gexit`
Expected: FAIL（`ChestCatalog` 未定義）

- [ ] **Step 3: Create procedural chest `content/models/chest/chest.gd`**

```gdscript
extends Node3D

# 程序化寶箱 placeholder（鏡射 town_oak_ext：.tscn + .gd 自建幾何）。
# @export opened 控制蓋子角度：closed=平蓋、open=掀起。
# 日後可把此 .gd 換成真模型，或直接改 .tscn 的 ext_resource 指向 GLB。

@export var opened: bool = false

const BODY := Vector3(0.9, 0.55, 0.6)
const LID_H := 0.2

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.30, 0.15)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = BODY
	body.mesh = bm
	body.material_override = mat
	body.position = Vector3(0.0, BODY.y / 2.0, 0.0)
	add_child(body)
	# 蓋子掛在後緣樞紐上，open 時向後掀起
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, BODY.y, -BODY.z / 2.0)
	add_child(pivot)
	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(BODY.x, LID_H, BODY.z)
	lid.mesh = lm
	lid.material_override = mat
	lid.position = Vector3(0.0, LID_H / 2.0, BODY.z / 2.0)
	pivot.add_child(lid)
	if opened:
		pivot.rotation.x = deg_to_rad(-110.0)
```

- [ ] **Step 4: Create `content/models/chest/chest_closed.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://content/models/chest/chest.gd" id="1_chest"]

[node name="ChestClosed" type="Node3D"]
script = ExtResource("1_chest")
opened = false
```

- [ ] **Step 5: Create `content/models/chest/chest_open.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://content/models/chest/chest.gd" id="1_chest"]

[node name="ChestOpen" type="Node3D"]
script = ExtResource("1_chest")
opened = true
```

- [ ] **Step 6: Create `presentation/world/chest_catalog.gd`**

```gdscript
class_name ChestCatalog
extends Object

# style id → 兩態場景路徑（鏡射 DecorationCatalog/ThemeCatalog）。
# 內容期把真模型加進來（換 .tscn 內容或指向 GLB）。
const _STYLES := {
	"chest": {
		"closed": "res://content/models/chest/chest_closed.tscn",
		"open": "res://content/models/chest/chest_open.tscn",
	},
}

static func has_style(id: String) -> bool:
	return _STYLES.has(id)

static func get_scene(id: String, opened: bool) -> PackedScene:
	if not _STYLES.has(id):
		return null
	var key := "open" if opened else "closed"
	return load(_STYLES[id][key])
```

- [ ] **Step 7: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_chest_catalog.gd -gexit`
Expected: PASS

> 若報「scene 載入失敗 / ext_resource 找不到 script」，先讓 Godot 匯入一次：`godot --headless --path . --import` 後再跑測試。

- [ ] **Step 8: Commit**

```bash
git add content/models/chest presentation/world/chest_catalog.gd tests/presentation/test_chest_catalog.gd
git commit -m "feat(world): 程序化寶箱兩態 placeholder + ChestCatalog（closed/open 場景）"
```

---

## Task 6: 寶箱渲染層 — ChestLayer

**Files:**
- Create: `presentation/world/chest_layer.gd`
- Test: `tests/presentation/test_chest_layer.gd`

**Interfaces:**
- Consumes: `MapData.objects`（Task 1）、catalog 的 `get_scene(id:String, opened:bool)->PackedScene`。
- Produces: `ChestLayer.build(map:MapData, opened:Dictionary, catalog=null)`（`opened` 為 `{Vector2i->true}` 集合；`catalog` 可注入，預設 `ChestCatalog`）。

- [ ] **Step 1: Write the failing test** — create `tests/presentation/test_chest_layer.gd`

```gdscript
extends GutTest

class FakeCatalog extends RefCounted:
	var scene: PackedScene
	var calls: Array = []   # [{id, opened}]
	func get_scene(id: String, opened: bool) -> PackedScene:
		calls.append({"id": id, "opened": opened})
		return scene

func _make_scene() -> PackedScene:
	var root := Node3D.new()
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps

func _map_with(objs: Array) -> MapData:
	var m := MapData.new()
	m.width = 5
	m.height = 5
	m.objects = objs
	return m

func _obj(pos: Vector2i) -> Dictionary:
	return {"pos": pos, "items": [], "gold": 0, "model": "chest"}

func test_one_node_per_object():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_obj(Vector2i(1, 1)), _obj(Vector2i(3, 1))]), {}, cat)
	assert_eq(layer.get_child_count(), 2)

func test_positions_node_at_cell():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_obj(Vector2i(2, 1))]), {}, cat)
	assert_eq((layer.get_child(0) as Node3D).position, GridGeometry.cell_to_world(Vector2i(2, 1)))

func test_opened_cell_requests_open_scene():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_obj(Vector2i(1, 1))]), {Vector2i(1, 1): true}, cat)
	assert_true(cat.calls[0]["opened"])

func test_closed_cell_requests_closed_scene():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_obj(Vector2i(1, 1))]), {}, cat)
	assert_false(cat.calls[0]["opened"])

func test_clears_previous_children():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_obj(Vector2i(0, 0))]), {}, cat)
	layer.build(_map_with([_obj(Vector2i(1, 1))]), {}, cat)
	assert_eq(layer.get_child_count(), 1)

func test_skips_unknown_model():
	var layer := ChestLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = null
	layer.build(_map_with([_obj(Vector2i(0, 0))]), {}, cat)
	assert_eq(layer.get_child_count(), 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_chest_layer.gd -gexit`
Expected: FAIL（`ChestLayer` 未定義）

- [ ] **Step 3: Implement `presentation/world/chest_layer.gd`**

```gdscript
class_name ChestLayer
extends Node3D

# 狀態感知寶箱渲染層：依 opened 集合（{Vector2i->true}）選 closed/open 場景。
# 切地圖時 build() 重建；開箱當下由 WorldStitchRenderer.refresh_objects 單區重建。
func build(map: MapData, opened: Dictionary, catalog = null) -> void:
	_clear()
	for obj in map.objects:
		var pos: Vector2i = obj["pos"]
		var is_open: bool = opened.has(pos)
		var scene: PackedScene = null
		if catalog != null:
			scene = catalog.get_scene(obj["model"], is_open)
		else:
			scene = ChestCatalog.get_scene(obj["model"], is_open)
		if scene == null:
			continue
		var inst := scene.instantiate()
		add_child(inst)
		if inst is Node3D:
			(inst as Node3D).position = GridGeometry.cell_to_world(pos)

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_chest_layer.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add presentation/world/chest_layer.gd tests/presentation/test_chest_layer.gd
git commit -m "feat(world): ChestLayer 依 opened 狀態渲染兩態寶箱（注入 catalog 可測）"
```

---

## Task 7: 拼裝渲染接線 — ChestLayer + refresh_objects

**Files:**
- Modify: `presentation/world/world_stitch_renderer.gd:8-10` (加 `opened_provider`)、`:44-53` (`_build_content` 加 ChestLayer)、加 `refresh_objects`/`_opened_set`
- Test: `tests/presentation/test_world_stitch_renderer.gd`

**Interfaces:**
- Consumes: `ChestLayer.build`（Task 6）、`GameState.opened_for`（Task 2）。
- Produces: `WorldStitchRenderer.refresh_objects(map:MapData)`（重建目前區 ChestLayer）、`opened_provider:Callable`（預設 `Callable(GameState,"opened_for")`，測試可注入）。

- [ ] **Step 1: Write the failing tests** — append to `tests/presentation/test_world_stitch_renderer.gd`

```gdscript
func _no_opened(_map_id: String) -> Array:
	return []

func _chest_layer_of(container: Node3D) -> ChestLayer:
	for c in container.get_children():
		if c is ChestLayer:
			return c
	return null

func test_default_path_builds_chest_layer():
	var a := _map("a", 3, 3)
	a.theme_id = "default"
	var t := PackedInt32Array()
	t.resize(9)
	a.tiles = t
	_world = { "a": a }
	var r := WorldStitchRenderer.new()
	r.loader = Callable(self, "_loader")
	r.opened_provider = Callable(self, "_no_opened")
	add_child_autofree(r)
	r.rebuild(a)
	var container: Node3D = r.get_child(0)
	assert_true(container.get_child(2) is ChestLayer, "容器含 ChestLayer（第三層）")

func test_refresh_objects_rebuilds_chest_layer():
	var a := _map("a", 3, 3)
	a.theme_id = "default"
	var t := PackedInt32Array()
	t.resize(9)
	a.tiles = t
	a.objects = [{"pos": Vector2i(1, 1), "items": [], "gold": 0, "model": "chest"}]
	_world = { "a": a }
	var r := WorldStitchRenderer.new()
	r.loader = Callable(self, "_loader")
	r.opened_provider = Callable(self, "_no_opened")
	add_child_autofree(r)
	r.rebuild(a)
	var cl := _chest_layer_of(r.get_child(0))
	assert_not_null(cl)
	assert_eq(cl.get_child_count(), 1, "一個寶箱物件 → 一個節點")
	# 模擬 stale：清空後 refresh 應重建
	for c in cl.get_children():
		cl.remove_child(c)
		c.free()
	assert_eq(cl.get_child_count(), 0)
	r.refresh_objects(a)
	assert_eq(cl.get_child_count(), 1, "refresh_objects 重建目標區 ChestLayer")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_world_stitch_renderer.gd -gexit`
Expected: FAIL（無 ChestLayer / 無 `refresh_objects`）

- [ ] **Step 3: Add `opened_provider` field**

在 `presentation/world/world_stitch_renderer.gd` 的 `var region_builder: Callable = Callable()`（第 10 行）之後新增：

```gdscript
# 開啟狀態提供者：map_id -> Array[Vector2i]。預設讀 GameState；測試可注入。
var opened_provider: Callable = Callable(GameState, "opened_for")
```

- [ ] **Step 4: Add ChestLayer in `_build_content`**

把 `_build_content` 末段（`var ol := ObjectLayer.new()` 三行）改為：

```gdscript
	var ol := ObjectLayer.new()
	container.add_child(ol)
	ol.build(map)
	var cl := ChestLayer.new()
	container.add_child(cl)
	cl.build(map, _opened_set(map.map_id))
```

- [ ] **Step 5: Add `refresh_objects` + `_opened_set`**

在檔案末端新增：

```gdscript
# 開箱當下：只重建「目前區」那一張圖的 ChestLayer（不動其他區、不動地形、不動 pooling）。
func refresh_objects(map: MapData) -> void:
	if map == null or not _regions.has(map.map_id):
		return
	var container: Node3D = _regions[map.map_id]
	for child in container.get_children():
		if child is ChestLayer:
			(child as ChestLayer).build(map, _opened_set(map.map_id))
			return

func _opened_set(map_id: String) -> Dictionary:
	var out: Dictionary = {}
	if opened_provider.is_valid():
		for pos in opened_provider.call(map_id):
			out[pos] = true
	return out
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_world_stitch_renderer.gd -gexit`
Expected: PASS（含既有 7 個測試不回歸）

- [ ] **Step 7: Commit**

```bash
git add presentation/world/world_stitch_renderer.gd tests/presentation/test_world_stitch_renderer.gd
git commit -m "feat(world): WorldStitchRenderer 渲染寶箱層 + refresh_objects 單區重建"
```

---

## Task 8: Y/N 確認 UI — ChestPrompt

**Files:**
- Create: `presentation/ui/chest_prompt.gd`
- Test: `tests/presentation/test_chest_prompt.gd`

**Interfaces:**
- Produces: `ChestPrompt`（extends CanvasLayer）：`open()`、`close()`、`is_open()->bool`、訊號 `confirmed`、`declined`。按 Y → 關閉並 `confirmed`；按 N → 關閉並 `declined`；關閉時不吃鍵。

- [ ] **Step 1: Write the failing test** — create `tests/presentation/test_chest_prompt.gd`

```gdscript
extends GutTest

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev

func _prompt() -> ChestPrompt:
	var p := ChestPrompt.new()
	add_child_autofree(p)
	return p

func test_starts_closed():
	assert_false(_prompt().is_open())

func test_open_then_y_confirms_and_closes():
	var p := _prompt()
	p.open()
	assert_true(p.is_open())
	watch_signals(p)
	p._unhandled_input(_key(KEY_Y))
	assert_signal_emitted(p, "confirmed")
	assert_false(p.is_open())

func test_open_then_n_declines_and_closes():
	var p := _prompt()
	p.open()
	watch_signals(p)
	p._unhandled_input(_key(KEY_N))
	assert_signal_emitted(p, "declined")
	assert_false(p.is_open())

func test_closed_ignores_keys():
	var p := _prompt()
	watch_signals(p)
	p._unhandled_input(_key(KEY_Y))
	assert_signal_not_emitted(p, "confirmed")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_chest_prompt.gd -gexit`
Expected: FAIL（`ChestPrompt` 未定義）

- [ ] **Step 3: Implement `presentation/ui/chest_prompt.gd`**

```gdscript
class_name ChestPrompt
extends CanvasLayer

# 程式建構的開箱確認覆蓋層（鏡射 SaveMenu 的 visible/open/close 慣例）。
# [Y] 確認開箱 / [N] 放棄。開啟期間 main 已停用 player 並擋其他選單，無按鍵衝突。

signal confirmed
signal declined

var _label: Label

func is_open() -> bool:
	return visible

func open() -> void:
	visible = true
	set_process_unhandled_input(true)

func close() -> void:
	visible = false
	set_process_unhandled_input(false)

func _ready() -> void:
	layer = 10
	visible = false
	_label = Label.new()
	_label.text = "打開寶箱？  [Y] 開 / [N] 不開"
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.add_theme_font_size_override("font_size", 28)
	add_child(_label)
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_Y:
		close()
		confirmed.emit()
	elif event.keycode == KEY_N:
		close()
		declined.emit()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_chest_prompt.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add presentation/ui/chest_prompt.gd tests/presentation/test_chest_prompt.gd
git commit -m "feat(ui): ChestPrompt 開箱 Y/N 確認覆蓋層"
```

---

## Task 9: 接線 — main.gd 觸發鏈 + Y/N 處理 + 戰後補跳

**Files:**
- Modify: `presentation/world/main.gd`（變數宣告、`_ready`、`_on_entered_cell`、`_on_combat_finished`、`_unhandled_input`，新增 chest 處理函式）
- Test: 無單元測試（main 為場景根 + 多 autoload 依賴，比照既有無 `test_main.gd`）；gate = 全套 333+綠不回歸 + 手動 `./run.sh`。

**Interfaces:**
- Consumes: `MapData.has_object/get_object`、`GameState.is_object_opened/mark_object_opened/gold/inventory`、`ChestLoot.grant`、`WorldStitchRenderer.refresh_objects`、`ChestPrompt`、`ItemCatalog.get_item`（既有）。

- [ ] **Step 1: Add member vars**

在 `var _mini_map: MiniMap`（第 28 行）之後新增：

```gdscript
var _chest_prompt: ChestPrompt
var _chest_pos: Vector2i
```

- [ ] **Step 2: Build + connect prompt in `_ready`**

在 `_spell_menu` 建立區塊之後、`_menus = [...]`（第 70 行）之前新增：

```gdscript
	_chest_prompt = ChestPrompt.new()
	add_child(_chest_prompt)
	_chest_prompt.confirmed.connect(_on_chest_confirmed)
	_chest_prompt.declined.connect(_on_chest_declined)
```

- [ ] **Step 3: Insert chest into `_on_entered_cell` 觸發鏈**

把 `_on_entered_cell` 內 encounter 區塊（第 105-107 行）之後、`var text :=`（第 108 行）之前插入：

```gdscript
	if _has_unopened_chest(pos):
		_prompt_chest(pos)
		return
```

- [ ] **Step 4: 戰後補跳——改 `_on_combat_finished` 勝利分支**

把 VICTORY 分支末的 `_player.set_enabled(true)`（第 196 行）改為：

```gdscript
		if _has_unopened_chest(_combat_pos):
			_prompt_chest(_combat_pos)
		else:
			_player.set_enabled(true)
```

（FLED / DEFEAT 分支不動。）

- [ ] **Step 5: Add chest helper functions**

在 `_on_combat_finished` 之後新增：

```gdscript
func _has_unopened_chest(pos: Vector2i) -> bool:
	var map := MapManager.current_map
	return map.has_object(pos) and not GameState.is_object_opened(map.map_id, pos)

func _prompt_chest(pos: Vector2i) -> void:
	_chest_pos = pos
	_player.set_enabled(false)
	_chest_prompt.open()

func _on_chest_confirmed() -> void:
	var map := MapManager.current_map
	var chest := map.get_object(_chest_pos)
	var res := ChestLoot.grant(chest, GameState.inventory)
	var gold := int(res["gold"])
	GameState.gold += gold
	GameState.mark_object_opened(map.map_id, _chest_pos)
	_world_renderer.refresh_objects(map)
	if gold > 0:
		GameState.message_log.push("獲得 %d 金幣。" % gold)
	for id in res["items"]:
		var item := ItemCatalog.get_item(id)
		var label: String = item.display_name if item != null else String(id)
		GameState.message_log.push("獲得道具：%s" % label)
	_player.set_enabled(true)
	_hud.refresh()

func _on_chest_declined() -> void:
	_player.set_enabled(true)
```

- [ ] **Step 6: 讓 prompt 維持 modal——`_unhandled_input` 加守門**

在 `_unhandled_input`（第 245 行）內，`if _combat != null: return`（第 248-249 行）之後新增：

```gdscript
	if _chest_prompt.is_open():
		return  # 開箱確認中，不開其他選單
```

- [ ] **Step 7: Run full suite — confirm no regression**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gexit`
Expected: 333/333 PASS（main 變更不影響既有測試；新增單元測試已在前序任務各自通過，這裡確認整合不破壞）

- [ ] **Step 8: Commit**

```bash
git add presentation/world/main.gd
git commit -m "feat(world): main 接線寶箱（踩格 Y/N + 戰後補跳 + 開箱發放/重繪）"
```

---

## Task 10: Demo 內容 — town_oak 普通 + 看守寶箱

**Files:**
- Modify: `content/maps/town_oak.json:5-7` (entities)
- Test: `tests/content/test_world_maps.gd`

**Interfaces:**
- Consumes: chest entity 解析（Task 1）、encounter 解析（既有，`"g"`=哥布林，見 `Bestiary`）。

- [ ] **Step 1: Write the failing test** — append to `tests/content/test_world_maps.gd`

```gdscript
func test_town_oak_has_demo_chests():
	var town := _load("town_oak")
	assert_true(town.has_object(Vector2i(1, 1)), "普通寶箱在 (1,1)")
	assert_eq(town.get_object(Vector2i(1, 1))["gold"], 50)
	assert_true(town.has_object(Vector2i(3, 1)), "看守寶箱在 (3,1)")
	assert_true(town.has_encounter(Vector2i(3, 1)), "(3,1) 同格有遭遇（看守怪）")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/content/test_world_maps.gd -gexit`
Expected: FAIL（town_oak 尚無 objects/encounter）

- [ ] **Step 3: Add chest entities to `content/maps/town_oak.json`**

把 `entities` 陣列改為（普通寶箱 (1,1)；看守寶箱 (3,1) 同格放 chest + monster）：

```json
  "entities": [
    { "type": "portal", "pos": [2, 3], "to": "wild_nw", "entry": "from_town" },
    { "type": "chest", "pos": [1, 1], "items": ["potion"], "gold": 50 },
    { "type": "chest", "pos": [3, 1], "items": ["short_sword"], "gold": 30 },
    { "type": "monster", "pos": [3, 1], "encounter": "g" }
  ],
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/content/test_world_maps.gd -gexit`
Expected: PASS

- [ ] **Step 5: Run full suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gexit`
Expected: 全綠（baseline 333 + 本計畫新增測試）

- [ ] **Step 6: Commit**

```bash
git add content/maps/town_oak.json tests/content/test_world_maps.gd
git commit -m "feat(content): town_oak demo 寶箱（普通 (1,1) + 看守 (3,1) 同格哥布林）"
```

---

## Final: 手動驗收（人工 `./run.sh`）

- [ ] **Step 1: 啟動遊戲**：`./run.sh`
- [ ] **Step 2: 普通寶箱**：從野外城門進橡鎮 → 走到 (1,1) → 跳「打開寶箱？[Y]開/[N]不開」→ 按 Y → 訊息顯示「獲得 50 金幣」「獲得道具：藥水」、寶箱模型變開蓋。
- [ ] **Step 3: 一次性**：對 (1,1) 開過的寶箱再踩 → 不再跳 prompt。
- [ ] **Step 4: 看守寶箱**：走到 (3,1) → 先遭遇哥布林戰鬥 → 勝利後自動跳開箱 prompt → Y → 拿到短劍+30 金幣、寶箱開蓋。
- [ ] **Step 5: 持久化**：在存讀檔選單（Tab）存檔 → 讀檔 → 已開寶箱仍是開蓋、踩上不跳 prompt；金幣/道具保留。
- [ ] **Step 6: 放棄**：踩另一個未開寶箱 → 按 N → 不發放、可日後再踩重開。

---

## Self-Review

**1. Spec coverage:**
- 資料模型（objects + chest 解析）→ Task 1 ✅
- opened_objects 狀態 → Task 2 ✅
- 存檔（serializer + capture/apply、v4 不升版、向後相容）→ Task 3 ✅
- ChestLoot.grant 純函式 → Task 4 ✅
- ChestCatalog + placeholder 素材 → Task 5 ✅
- ChestLayer（兩態渲染）→ Task 6 ✅
- WorldStitchRenderer 接線 + refresh_objects + opened_provider → Task 7 ✅
- ChestPrompt（Y/N）→ Task 8 ✅
- main 觸發鏈（link→encounter→chest→tile）、戰後補跳、modal 守門 → Task 9 ✅
- demo 內容（town_oak 普通 + 看守）→ Task 10 ✅
- 驗收（run.sh 六項）→ Final ✅

**2. Placeholder scan:** 無 TBD/TODO；所有 code step 含完整程式碼；素材用程序化 placeholder（非缺口）。`_load` 既有於 test_world_maps.gd ✅。

**3. Type consistency:**
- `get_scene(id, opened)` 兩參數在 ChestCatalog（Task 5）、ChestLayer 注入 catalog（Task 6）、FakeCatalog 一致 ✅
- `opened` 集合型別 `{Vector2i->true}`：ChestLayer.build 用 `.has(pos)`、WorldStitchRenderer `_opened_set` 產生、測試注入一致 ✅
- `opened_objects` map_id→`Array[Vector2i]`：GameState（Task 2）、SaveData/serializer（Task 3）、`opened_provider`（Task 7）一致 ✅
- `ChestLoot.grant` 回 `{"gold":int,"items":Array[String]}`：Task 4 定義、Task 9 消費 (`res["gold"]`/`res["items"]`) 一致 ✅
- `refresh_objects(map)`、`has_object/get_object`、`mark_object_opened/is_object_opened` 命名跨任務一致 ✅
