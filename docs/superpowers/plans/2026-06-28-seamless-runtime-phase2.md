# Seamless Runtime Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把全部怪物（當前圖 + 8 鄰）放上統一 `WorldGrid`（全域 cell + 全域 home + 怪身分綁原生 encounter map），讓鄰圖怪會真的跨界追擊與接觸開戰。

**Architecture:** `OverworldMonsters` entry 加 `origin_map`/`origin_off`、home/cell 改全域；新增 `init_from_regions`（吃 `WorldGrid.regions()` 把所有圖的怪投影成統一 live 集，吸收並取代 `NeighborMonsters`）、`to_save` 改 group-by-origin、`combat_info` 供跨界戰鬥身分。`main` 單層畫全部怪、每步寫所有 origin_map slice、`_is_passable` 回統一 grid、contact→combat 用原生 (map, home_local, group)。狀態機 `step`/BFS 完全不動。

**Tech Stack:** Godot 4.7 (GDScript)、GUT 9.7。

## Global Constraints

- 給使用者的說明/建議一律繁體中文（程式碼/commit 訊息維持既有慣例）。
- 所有 subagent 一律繼承 parent model，dispatch 不傳 model 參數。
- 本 plan **不新增 class_name**（`OverworldMonsters` 既有）→ 無 `.gd.uid` 新檔；刪 `NeighborMonsters` 時一併刪其 `.gd.uid`。
- **存檔不升版**：`monster_state` 結構不變（`map_id → {uid → {cell, state}}`），cell 語意擴充為「原生相對 local」（可越界）；不改 `save_serializer`、不寫相容層。
- 每個 task commit 前確認分支仍為 `feat/seamless-runtime-world`。
- `godot` 不在 PATH 用 `/Applications/Godot.app/Contents/MacOS/Godot`。
- 單檔測試：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<file>.gd -gexit`
- 全套：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Headless boot smoke：`timeout 8 ./run.sh --headless 2>&1 | grep -iE "SCRIPT ERROR|Parser Error|Cannot call|nil|null instance|Invalid (get|call)" || echo BOOT_CLEAN`（expect BOOT_CLEAN）。
- 起點：分支 tip `e611e06`（Phase 1 已併入 base、spec 已 commit），全套 756/756 綠。
- pre-release：breaking change 一律可接受、不寫相容層。

---

## File Structure

- **Modify** `engine/world/overworld_monsters.gd` — entry 加 `origin_map`/`origin_off`；`_add_map` builder；`init_from_map` 用之；`init_from_regions`（多圖）；`to_save` group-by-origin；`combat_info`。狀態機 `step`/`_chase`/`next_step`/`live`/`home_of`/`remove`/`apply_saved` 不動邏輯。
- **Modify** `tests/engine/world/test_overworld_monsters.gd` — `_mk` 加 origin 欄位；改寫 to_save 測試；加 combat_info/init_from_regions/round-trip 測試；移除 `test_save_roundtrip`（改由 regions round-trip）。
- **Delete** `engine/world/neighbor_monsters.gd`（+ `.gd.uid`）、`tests/engine/world/test_neighbor_monsters.gd`（+ `.gd.uid`）— 功能併入 `init_from_regions`（在 Task 3 main 移除引用後刪）。
- **Modify** `presentation/world/main.gd` — 單層 `_monster_layer`（移除 `_neighbor_monster_layer`）；`_rebuild_monsters_for_current_map` 改 `init_from_regions`；每步寫所有 origin_map slice；`_is_passable` 回統一 grid；contact→combat 用 `combat_info`、勝利清原生圖、chest guard origin-aware。
- **Unchanged** `presentation/world/monster_layer.gd`（已用全域 cell 畫）。

---

## Task 1: OverworldMonsters — origin-aware entries + grouped to_save + combat_info

Entry 加 `origin_map`/`origin_off`、home/cell 視為全域；`to_save` 改 group-by-origin（投影回原生相對 local）；新增 `combat_info`。狀態機不動。

**Files:**
- Modify: `engine/world/overworld_monsters.gd`
- Test: `tests/engine/world/test_overworld_monsters.gd`

**Interfaces:**
- Produces:
  - entry 形狀：`{ uid, group, origin_map:String, origin_off:Vector2i, home:Vector2i, cell:Vector2i, state:int }`（home/cell 為全域）。
  - `init_from_map(map: MapData, is_defeated: Callable)`（單圖特例：origin_off=(0,0)、home/cell=local）。
  - `to_save() -> Dictionary`：`{ origin_map: { uid: { "cell": Vector2i(原生相對 local), "state": int } } }`。
  - `combat_info(uid: String) -> Dictionary`：`{ "group": String, "origin_map": String, "home_local": Vector2i }`，未知回 `{}`。
  - 私有 `_add_map(map, offset, is_defeated, saved)`（Task 2 的 `init_from_regions` 會用）。

- [ ] **Step 1: 改測試（_mk 加 origin 欄位、改寫 to_save 測試、加 combat_info 測試、移除舊 round-trip）**

在 `tests/engine/world/test_overworld_monsters.gd`：

(a) 把 `_mk` 改為（加 `origin_map`/`origin_off`）：
```gdscript
func _mk(uid: String, home: Vector2i, cell: Vector2i, state: int) -> Dictionary:
	return {"uid": uid, "group": "g", "origin_map": "m", "origin_off": Vector2i.ZERO, "home": home, "cell": cell, "state": state}
```

(b) 把既有 `test_to_save_format` 整段**換成**下面兩個測試，並**整段刪除** `test_save_roundtrip`（其 round-trip 由 Task 2 的 regions round-trip 取代；保留 `test_apply_saved_overwrites_cell_and_state_keeps_home` 與 `test_apply_saved_leaves_unlisted_at_defaults` 不動）：
```gdscript
func test_to_save_groups_by_origin_map():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(3, 4), OverworldMonsters.State.CHASING)])
	var saved := om.to_save()
	assert_true(saved.has("m"), "以 origin_map 分組")
	assert_eq(saved["m"]["a"]["cell"], Vector2i(3, 4), "origin_off=0 → 原生相對 == 全域")
	assert_eq(saved["m"]["a"]["state"], OverworldMonsters.State.CHASING)

func test_to_save_projects_global_back_to_origin_relative():
	# 東鄰 origin_off=(5,0)、全域 cell=(6,2) → 原生相對 = (1,2)
	var e := _mk("a", Vector2i(5, 0), Vector2i(6, 2), OverworldMonsters.State.IDLE)
	e["origin_off"] = Vector2i(5, 0)
	var om := _om([e])
	assert_eq(om.to_save()["m"]["a"]["cell"], Vector2i(1, 2), "全域 - origin_off = 原生相對 local")
```

(c) 加 `combat_info` 與 `init_from_map` 設好 origin 的測試：
```gdscript
func test_combat_info_returns_group_origin_home_local():
	var e := _mk("a", Vector2i(7, 2), Vector2i(9, 2), OverworldMonsters.State.CHASING)
	e["origin_map"] = "north"
	e["origin_off"] = Vector2i(5, 0)
	var om := _om([e])
	var info := om.combat_info("a")
	assert_eq(info["group"], "g")
	assert_eq(info["origin_map"], "north")
	assert_eq(info["home_local"], Vector2i(2, 2), "home(7,2) - origin_off(5,0) = (2,2)")

func test_combat_info_unknown_returns_empty():
	assert_eq(_om([]).combat_info("nope"), {})

func test_init_from_map_sets_origin_fields():
	var map := _map_with_encounters()
	map.map_id = "home"
	var om := OverworldMonsters.new()
	om.init_from_map(map, Callable(self, "_none_defeated"))
	var saved := om.to_save()
	assert_true(saved.has("home"), "init_from_map 設好 origin_map")
	assert_true(saved["home"].has("u-g"))
	assert_eq(saved["home"]["u-g"]["cell"], Vector2i(2, 2), "origin_off=0 → 原生相對 == local")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: FAIL（`combat_info` 不存在；`to_save` 仍是 flat 格式）

- [ ] **Step 3: 改實作**

在 `engine/world/overworld_monsters.gd`：

(a) 把 `init_from_map` 換成（改用 `_add_map`），並在其後加 `_add_map`：
```gdscript
# 從地圖 encounter 建怪清單（單圖特例：放在全域原點）。
func init_from_map(map: MapData, is_defeated: Callable) -> void:
	_list.clear()
	_add_map(map, Vector2i.ZERO, is_defeated, {})

# 把一張圖的 encounters 投影成全域 entry 加入 _list。
# offset=該圖在當前框架的全域偏移；saved（該圖 { uid:{cell:原生相對 local, state} }）相符 uid 覆寫 cell(+offset)/state。
func _add_map(map: MapData, offset: Vector2i, is_defeated: Callable, saved: Dictionary) -> void:
	for cell in map.encounters:
		var uid := map.get_encounter_uid(cell)
		if is_defeated.is_valid() and is_defeated.call(uid):
			continue
		var home_global: Vector2i = cell + offset
		var cur := home_global
		var st := State.IDLE
		if saved.has(uid):
			var rec: Dictionary = saved[uid]
			cur = Vector2i(rec["cell"]) + offset
			st = int(rec["state"])
		_list.append({
			"uid": uid,
			"group": map.get_encounter(cell),
			"origin_map": map.map_id,
			"origin_off": offset,
			"home": home_global,
			"cell": cur,
			"state": st,
		})
```

(b) 把 `to_save` 換成 group-by-origin：
```gdscript
# 回 { origin_map: { uid: {"cell": Vector2i(原生相對 local), "state": int} } }。
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for m in _list:
		var mid: String = m["origin_map"]
		if not out.has(mid):
			out[mid] = {}
		out[mid][m["uid"]] = {"cell": m["cell"] - m["origin_off"], "state": m["state"]}
	return out
```

(c) 在 `to_save` 之後加 `combat_info`：
```gdscript
# 戰鬥身分：回 { group, origin_map, home_local }（home_local = 全域 home - origin_off = 原生圖上的 home 格）。
func combat_info(uid: String) -> Dictionary:
	for m in _list:
		if m["uid"] == uid:
			return {"group": m["group"], "origin_map": m["origin_map"], "home_local": m["home"] - m["origin_off"]}
	return {}
```

（`apply_saved`、`step`、`_chase`、`_step_one`、`next_step`、`live`、`home_of`、`remove`、`cheb`、`_occupied_set`、`_as_set` 全不動。）

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: PASS（含改寫的 to_save + combat_info + init_from_map origin 測試；既有 step/lifecycle 測試續綠，因 `live()` 不外洩 origin）

- [ ] **Step 5: Commit**

```bash
git add engine/world/overworld_monsters.gd tests/engine/world/test_overworld_monsters.gd
git commit -m "feat(world): OverworldMonsters origin-aware entries + grouped to_save + combat_info"
```

---

## Task 2: OverworldMonsters.init_from_regions（多圖統一怪集）

新增 `init_from_regions`：吃 `WorldGrid.regions()` 的所有圖，把每張圖的 encounter 投影成全域 entry、套該圖存檔，產出一個統一的 live 怪集（含當前圖 + 鄰圖）。吸收 `NeighborMonsters.collect` 的偏移邏輯，但產「真的活的怪」。

**Files:**
- Modify: `engine/world/overworld_monsters.gd`
- Test: `tests/engine/world/test_overworld_monsters.gd`

**Interfaces:**
- Consumes: `_add_map`（Task 1）。
- Produces: `init_from_regions(regions: Array, is_defeated: Callable, saved_provider: Callable)` — `regions` = `[{ "map": MapData, "ox": int, "oy": int }]`（= `WorldGrid.regions()`）；`saved_provider(map_id: String) -> Dictionary`（回該圖 `{uid:{cell:原生相對 local, state}}`，非 Dictionary 當空）。

- [ ] **Step 1: 寫失敗測試**

在 `tests/engine/world/test_overworld_monsters.gd` 末尾加：
```gdscript
func _enc_map(id: String, w: int, h: int, encs: Dictionary, uids: Dictionary) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.encounters = encs
	m.encounter_uids = uids
	return m

func _region(map: MapData, ox: int, oy: int) -> Dictionary:
	return {"map": map, "ox": ox, "oy": oy}

func _no_saved(_map_id: String) -> Dictionary:
	return {}

func test_init_from_regions_projects_current_and_neighbor_to_global():
	var a := _enc_map("a", 5, 5, {Vector2i(0, 0): "g"}, {Vector2i(0, 0): "u-a"})
	var e := _enc_map("e", 5, 5, {Vector2i(1, 2): "g"}, {Vector2i(1, 2): "u-e"})
	var om := OverworldMonsters.new()
	om.init_from_regions([_region(a, 0, 0), _region(e, 5, 0)], Callable(self, "_none_defeated"), Callable(self, "_no_saved"))
	var rows := om.live()
	assert_eq(rows.size(), 2, "含當前圖 + 鄰圖（統一 live 集）")
	var by_uid := {}
	for r in rows:
		by_uid[r["uid"]] = r
	assert_eq(by_uid["u-a"]["cell"], Vector2i(0, 0), "當前圖在原點")
	assert_eq(by_uid["u-e"]["cell"], Vector2i(6, 2), "鄰圖怪投影到全域 (1+5, 2)")

func test_init_from_regions_excludes_defeated():
	var e := _enc_map("e", 5, 5, {Vector2i(1, 1): "g"}, {Vector2i(1, 1): "u-e"})
	var is_def := func(uid: String) -> bool: return uid == "u-e"
	var om := OverworldMonsters.new()
	om.init_from_regions([_region(e, 0, 0)], is_def, Callable(self, "_no_saved"))
	assert_eq(om.live().size(), 0)

func test_init_from_regions_applies_saved_with_offset():
	var e := _enc_map("e", 5, 5, {Vector2i(1, 1): "g"}, {Vector2i(1, 1): "u-e"})
	var saved := func(mid: String) -> Dictionary:
		if mid == "e":
			return {"u-e": {"cell": Vector2i(3, 3), "state": OverworldMonsters.State.CHASING}}
		return {}
	var om := OverworldMonsters.new()
	om.init_from_regions([_region(e, 5, 0)], Callable(self, "_none_defeated"), saved)
	var m: Dictionary = om.live()[0]
	assert_eq(m["cell"], Vector2i(8, 3), "原生相對(3,3) + offset(5,0) = 全域(8,3)")
	assert_eq(m["state"], OverworldMonsters.State.CHASING)

func test_init_from_regions_handles_non_dictionary_saved():
	var e := _enc_map("e", 5, 5, {Vector2i(0, 0): "g"}, {Vector2i(0, 0): "u-e"})
	var bad := func(_mid: String): return null
	var om := OverworldMonsters.new()
	om.init_from_regions([_region(e, 5, 0)], Callable(self, "_none_defeated"), bad)
	assert_eq(om.live()[0]["cell"], Vector2i(5, 0), "non-dict saved → 當空、用 home(全域)")

func test_init_from_regions_roundtrip_with_wandered_monster():
	# 怪被引離原生圖：e 為東鄰(ox=5)，存檔越界原生相對 (-1,2) → 全域 (4,2)（已踏進西側當前圖）
	var e := _enc_map("e", 5, 5, {Vector2i(1, 1): "g"}, {Vector2i(1, 1): "u-e"})
	var saved := func(mid: String) -> Dictionary:
		if mid == "e":
			return {"u-e": {"cell": Vector2i(-1, 2), "state": OverworldMonsters.State.CHASING}}
		return {}
	var om := OverworldMonsters.new()
	om.init_from_regions([_region(e, 5, 0)], Callable(self, "_none_defeated"), saved)
	assert_eq(om.live()[0]["cell"], Vector2i(4, 2), "越界原生相對也能投影（怪已跨界）")
	assert_eq(om.to_save()["e"]["u-e"]["cell"], Vector2i(-1, 2), "to_save 投影回越界原生相對（round-trip）")

func test_init_from_regions_skips_null_map():
	var om := OverworldMonsters.new()
	om.init_from_regions([{"map": null, "ox": 0, "oy": 0}], Callable(self, "_none_defeated"), Callable(self, "_no_saved"))
	assert_eq(om.live().size(), 0, "region map 為 null → 略過、不崩")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: FAIL（`init_from_regions` 不存在）

- [ ] **Step 3: 實作 `init_from_regions`**

在 `engine/world/overworld_monsters.gd` 的 `_add_map` 之後加：
```gdscript
# 從 WorldGrid.regions()（[{map, ox, oy}]）建統一全域怪集（含當前圖 + 鄰圖）。
# is_defeated 注入；saved_provider(map_id) 回該圖 { uid:{cell:原生相對 local, state} }（非 Dictionary 當空）。
func init_from_regions(regions: Array, is_defeated: Callable, saved_provider: Callable) -> void:
	_list.clear()
	for region in regions:
		var map: MapData = region["map"]
		if map == null:
			continue
		var offset := Vector2i(int(region["ox"]), int(region["oy"]))
		var saved = saved_provider.call(map.map_id)
		if typeof(saved) != TYPE_DICTIONARY:
			saved = {}
		_add_map(map, offset, is_defeated, saved)
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add engine/world/overworld_monsters.gd tests/engine/world/test_overworld_monsters.gd
git commit -m "feat(world): OverworldMonsters.init_from_regions — unified global monster set from 3x3"
```

---

## Task 3: main — 單層統一怪集 + 每步寫所有 origin_map slice + is_passable 回統一 grid

main 改用 `init_from_regions` 建單一 live 怪集、移除第二層與 `NeighborMonsters`、每步寫所有受模擬圖的 monster_state slice、`_is_passable` 回統一 grid（怪可跨界走）。

> main 為場景 wiring（無單測）。本 task 完成後 contact→combat 對「當前圖怪」仍正常；「跨界怪接觸」會 no-op（戰鬥身分尚未跨界，Task 4 補）。以全套綠 + boot smoke 驗證。

**Files:**
- Modify: `presentation/world/main.gd`
- Delete: `engine/world/neighbor_monsters.gd`、`engine/world/neighbor_monsters.gd.uid`、`tests/engine/world/test_neighbor_monsters.gd`、`tests/engine/world/test_neighbor_monsters.gd.uid`

**Interfaces:**
- Consumes: `OverworldMonsters.init_from_regions`（Task 2）、`OverworldMonsters.to_save`（Task 1，grouped）、`WorldGrid.regions()`（Phase 1）。

- [ ] **Step 1: 移除第二層欄位與建立**

在 `presentation/world/main.gd`：
- 刪除欄位宣告 `var _neighbor_monster_layer: MonsterLayer`。
- 在 `_ready` 刪除這兩行：
```gdscript
	_neighbor_monster_layer = MonsterLayer.new()
	add_child(_neighbor_monster_layer)
```

- [ ] **Step 2: `_rebuild_monsters_for_current_map` 改 init_from_regions（單層）**

把：
```gdscript
func _rebuild_monsters_for_current_map() -> void:
	var map := MapManager.current_map
	_overworld_monsters = OverworldMonsters.new()
	_overworld_monsters.init_from_map(map, Callable(GameState, "is_defeated"))
	_overworld_monsters.apply_saved(GameState.monster_state.get(map.map_id, {}))
	_monster_layer.rebuild(_overworld_monsters.live())
	var neighbors := NeighborMonsters.collect(map, Callable(MapManager, "peek_map"), Callable(GameState, "is_defeated"), Callable(self, "_saved_monster_state"))
	_neighbor_monster_layer.rebuild(neighbors)
```
換成：
```gdscript
func _rebuild_monsters_for_current_map() -> void:
	_overworld_monsters = OverworldMonsters.new()
	_overworld_monsters.init_from_regions(_world_grid.regions(), Callable(GameState, "is_defeated"), Callable(self, "_saved_monster_state"))
	_monster_layer.rebuild(_overworld_monsters.live())
```
（`_saved_monster_state(map_id)` 保留不動。4 個重建點都已在各自 `_build_world_grid()` 之後呼叫本函式，故 `_world_grid.regions()` 為新框架。）

- [ ] **Step 3: 每步寫所有 origin_map slice + helper**

在 `_on_entered_cell` 把：
```gdscript
	GameState.monster_state[GameState.current_map_id] = _overworld_monsters.to_save()
```
換成：
```gdscript
	_write_monster_state(_overworld_monsters.to_save())
```
並在 `_saved_monster_state` 之後加 helper：
```gdscript
# to_save 現為 { origin_map: {uid:{cell,state}} }；逐 origin_map 寫回（怪可被引離原生圖，故非只當前圖）。
func _write_monster_state(saved: Dictionary) -> void:
	for mid in saved:
		GameState.monster_state[mid] = saved[mid]
```

- [ ] **Step 4: `_is_passable` 回統一 grid**

把 Phase 1 的 focus-bound：
```gdscript
func _is_passable(cell: Vector2i) -> bool:
	# Phase 1：怪物 passability 侷限焦點圖（鄰圖格留待 Phase 2 全怪上統一 grid）。
	# 焦點圖在統一 grid 原點 → local==global；超出焦點圖寬高即牆，等價於舊 current_grid.is_walkable。
	var m := MapManager.current_map
	if cell.x < 0 or cell.x >= m.width or cell.y < 0 or cell.y >= m.height:
		return false
	return _world_grid.is_walkable(cell)
```
換成：
```gdscript
func _is_passable(cell: Vector2i) -> bool:
	return _world_grid.is_walkable(cell)   # Phase 2：怪可跨界走（統一 grid；外緣無鄰 = 牆）
```

- [ ] **Step 5: 刪除 NeighborMonsters（main 已不引用）**

先確認 main 已無 `NeighborMonsters` 引用：
```bash
grep -rn "NeighborMonsters" --include=*.gd . | grep -v '\.claude/worktrees'
```
Expected: 僅 `engine/world/neighbor_monsters.gd`（定義）與 `tests/engine/world/test_neighbor_monsters.gd`（測試）；**main.gd 應已無引用**。若 main.gd 仍出現，回 Step 2 修正。
然後刪檔：
```bash
git rm engine/world/neighbor_monsters.gd engine/world/neighbor_monsters.gd.uid tests/engine/world/test_neighbor_monsters.gd tests/engine/world/test_neighbor_monsters.gd.uid
```

- [ ] **Step 6: 全套 + boot smoke 驗證**

Run（全套）: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全綠（移除 test_neighbor_monsters 後總數下降；無 `NeighborMonsters` 殘留錯誤）。

Run（boot）: `timeout 8 ./run.sh --headless 2>&1 | grep -iE "SCRIPT ERROR|Parser Error|Cannot call|nil|null instance|Invalid (get|call)" || echo BOOT_CLEAN`
Expected: BOOT_CLEAN。

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(world): unified single-layer monsters via init_from_regions; drop NeighborMonsters + neighbor layer"
```

---

## Task 4: main — 跨界 contact→combat（combat_info、清原生圖、origin-aware chest guard）

contact→combat 改用怪的原生身分（group/origin_map/home_local），讓鄰圖怪接觸能正確開戰；勝利清原生圖的 encounter；chest 自動開 guard 改 origin-aware。

> main wiring（無單測）。以全套綠 + boot smoke + 人工 gate 驗證。

**Files:**
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes: `OverworldMonsters.combat_info`（Task 1）、`_write_monster_state`（Task 3）、`GameState.mark_encounter_cleared(map_id, pos)` / `notify_encounter_defeated(uid)` / `is_object_opened`（既有）。

- [ ] **Step 1: 戰鬥身分欄位改原生 (map, home_local)**

在 `presentation/world/main.gd` 把欄位宣告 `var _combat_pos: Vector2i` 換成：
```gdscript
var _combat_origin_map: String = ""
var _combat_home_local: Vector2i
```

- [ ] **Step 2: `_start_combat_for_uid` 用 combat_info；`_start_combat` 改 `_start_combat_with_group`**

把：
```gdscript
func _start_combat(pos: Vector2i) -> void:
	var id := MapManager.current_map.get_encounter(pos)
	var defs := Bestiary.group_defs_for(id)
	if defs.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var group := EncounterSystem.build_group(defs)
	_combat = CombatSystem.new(GameState.party, group, rng)
	_combat_pos = pos
	_player.set_enabled(false)
	GameState.message_log.push("遭遇怪物！")
	_set_overworld_hud_visible(false)
	_combat_layer.begin(_combat, _camera)
```
換成（改吃 group id、不再讀 current_map）：
```gdscript
func _start_combat_with_group(group: String) -> void:
	var defs := Bestiary.group_defs_for(group)
	if defs.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var grp := EncounterSystem.build_group(defs)
	_combat = CombatSystem.new(GameState.party, grp, rng)
	_player.set_enabled(false)
	GameState.message_log.push("遭遇怪物！")
	_set_overworld_hud_visible(false)
	_combat_layer.begin(_combat, _camera)
```
並把：
```gdscript
func _start_combat_for_uid(uid: String) -> void:
	_combat_uid = uid
	_start_combat(_overworld_monsters.home_of(uid))   # 戰鬥身分錨在 home 格（MapData 仍持有 group/uid）
```
換成：
```gdscript
func _start_combat_for_uid(uid: String) -> void:
	var info := _overworld_monsters.combat_info(uid)
	if info.is_empty():
		return
	_combat_uid = uid
	_combat_origin_map = info["origin_map"]      # 戰鬥身分錨在原生 (map, home_local)，可跨界
	_combat_home_local = info["home_local"]
	_start_combat_with_group(info["group"])
```

- [ ] **Step 3: 勝利分支改用原生身分清除/擊敗 + origin-aware chest guard**

把 `_on_combat_finished` 的 VICTORY 區塊：
```gdscript
	if result == CombatSystem.Result.VICTORY:
		_grant_rewards()
		_grant_drops()
		GameState.notify_encounter_defeated(MapManager.current_map.get_encounter_uid(_combat_pos))
		GameState.refresh_collect()
		MapManager.current_map.clear_encounter(_combat_pos)
		GameState.mark_encounter_cleared(MapManager.current_map.map_id, _combat_pos)
		_overworld_monsters.remove(_combat_uid)
		_monster_layer.rebuild(_overworld_monsters.live())
		GameState.monster_state[MapManager.current_map.map_id] = _overworld_monsters.to_save()
		GameState.message_log.push("戰鬥勝利！")
		# 怪會走動：戰鬥錨在 home 格，但若怪是被引離 home 才打死，玩家此刻不在 home，
		# 不該遠端開該格的寶箱（遭遇已清除，玩家日後踏到該格時由 _on_entered_cell 正常提示）。
		if _combat_pos == GameState.player_pos and _has_unopened_chest(_combat_pos):
			_prompt_chest(_combat_pos)
		else:
			_player.set_enabled(true)
```
換成（uid 直接拿、清原生圖、寫所有 slice、guard origin-aware）：
```gdscript
	if result == CombatSystem.Result.VICTORY:
		_grant_rewards()
		_grant_drops()
		GameState.notify_encounter_defeated(_combat_uid)
		GameState.refresh_collect()
		GameState.mark_encounter_cleared(_combat_origin_map, _combat_home_local)   # 持久層；origin_map 可非 current_map
		_overworld_monsters.remove(_combat_uid)
		_monster_layer.rebuild(_overworld_monsters.live())
		_write_monster_state(_overworld_monsters.to_save())
		GameState.message_log.push("戰鬥勝利！")
		# 戰鬥身分錨在原生 (origin_map, home_local)；怪可能從鄰圖被引來、或在別圖被打死。
		# 只有「原生圖＝玩家所在圖 且 home_local＝玩家格」才在當下提示開箱（引離/跨界擊殺不遠端開箱）。
		if _combat_origin_map == GameState.current_map_id and _combat_home_local == GameState.player_pos and _has_unopened_chest(_combat_home_local):
			_prompt_chest(_combat_home_local)
		else:
			_player.set_enabled(true)
```
並把函式結尾的 `_combat_uid = ""` 換成（一併重置原生身分）：
```gdscript
	_combat_uid = ""
	_combat_origin_map = ""
```

- [ ] **Step 4: 全套 + boot smoke 驗證**

先確認無 `_combat_pos` / 舊 `_start_combat(` 殘留：
```bash
grep -nE "_combat_pos|_start_combat\(" presentation/world/main.gd
```
Expected: 無輸出（`_combat_pos` 全移除；只剩 `_start_combat_with_group(` 與 `_start_combat_for_uid(`）。

Run（全套）: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全綠、pristine。

Run（boot）: `timeout 8 ./run.sh --headless 2>&1 | grep -iE "SCRIPT ERROR|Parser Error|Cannot call|nil|null instance|Invalid (get|call)" || echo BOOT_CLEAN`
Expected: BOOT_CLEAN。

- [ ] **Step 5: Commit**

```bash
git add presentation/world/main.gd
git commit -m "feat(world): cross-map contact->combat via origin identity (combat_info); origin-aware clear + chest guard"
```

---

## 人工視覺 gate（交付後請使用者 `./run.sh`）

往東北走：鄰圖的怪會**真的跨界朝玩家移動並追上來**；接觸後**開打**；戰鬥怪**腳貼地**；被引離原生圖打死後不遠端開箱、該怪不再復活。

---

## Self-Review（plan↔spec 對照）

- **Spec coverage：** OverworldMonsters origin-aware + init_from_regions(吸收 NeighborMonsters)(Task 1–2) ✓；單層畫全部怪 + 移除 NeighborMonsters/第二層(Task 3) ✓；每步寫所有 origin_map slice(Task 3) ✓；`_is_passable` 回統一 grid(Task 3) ✓；contact→combat 跨界用 combat_info/原生 (map,home_local,group)(Task 4) ✓；勝利清原生圖 + origin-aware chest guard(Task 4) ✓；leash 全域(狀態機不動，home/cell 全域 → 自動)(Task 1) ✓；存檔不升版(Global Constraints；結構不變) ✓。
- **狀態機不動：** `step`/`_chase`/`_step_one`/`next_step` 完全未改；本就吃全域 cell + 注入 is_passable。
- **型別一致：** entry `{uid,group,origin_map,origin_off,home,cell,state}`、`to_save()->{origin_map:{uid:{cell,state}}}`、`combat_info(uid)->{group,origin_map,home_local}`、`init_from_regions(regions,is_defeated,saved_provider)`、`_write_monster_state(saved)`、`_start_combat_with_group(group)`、欄位 `_combat_origin_map`/`_combat_home_local` 全 plan 內一致。
- **中間態（與 Phase 1 同模式）：** Task 1–2 改 OverworldMonsters 後、Task 3 前，main 仍用舊 to_save/init_from_map 寫法 → 行為暫不正確但無測試載入 main、suite 續綠；Task 3 後「跨界怪接觸」暫 no-op，Task 4 補齊。最終態（Task 4）由 boot smoke + 人工 gate 驗證。
- **dead code 待終審 triage：** Task 3 後 `init_from_map` / `apply_saved` 變僅測試使用（init_from_regions 用 `_add_map`，不經這兩者）；保留為單圖 utility，終審決定是否刪。
- **Placeholder scan：** 無 TBD/TODO；每個改碼步驟均附完整程式碼。
