# 大地圖會走動的怪物（MM3 風）+ 怪物貼地 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make overworld monsters roam the 3D map (MM3-style step-based pursuit with aggro/leash), trigger combat on contact, and stand feet-on-floor at the same size in both overworld and combat (fixing the floating-monster bug).

**Architecture:** A pure `OverworldMonsters` RefCounted state machine (IDLE/CHASING/RETURNING + BFS pathing, all dependencies injected, no autoload) drives monster movement one step per player step. A `MonsterLayer` Node3D renders one billboard per group at floor level, reusing `CombatStage`'s size/feet anchor constants so overworld and combat sprites match. Combat identity stays anchored at each monster's home cell (the original `MapData` encounter cell), so existing combat build/clear logic is reused unchanged. Monster positions persist via a new save v11 `monster_state` field, rewritten every player step.

**Tech Stack:** Godot 4.7 (GDScript), GUT test framework.

## Global Constraints

- **Godot binary:** `godot` is on PATH (4.7.stable). If a future environment lacks it, use `/Applications/Godot.app/Contents/MacOS/Godot`.
- **New `class_name` `.gd` files:** after creating, run `godot --headless --path . --import` to generate the `.gd.uid` sidecar, then commit the `.gd.uid` alongside the `.gd` (applies to both source and test files).
- **Single-file test:** `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<file>.gd -gexit`
- **Full suite:** `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- **No backward compatibility:** save bumps to v11; delete old-version acceptance, update ALL call sites and existing test data to v11, write no compatibility layer.
- **GDScript 4.7 gotcha:** never use `:=` (inferred) on a Variant rvalue (e.g. a Dictionary element access like `m["cell"]`). Use an explicit type annotation instead: `var x: Vector2i = m["cell"]`. `:=` is fine only when the rvalue has a concrete static type.
- **Communication to the user is Traditional Chinese**; code/comments/commit messages keep existing conventions (Chinese comments as in the codebase).
- **Sub-agents inherit the parent model**; never pass a model override.

## Tunable Constants (verbatim from spec)

| Constant | Value | Location |
|---|---|---|
| `AGGRO_RANGE` | `4` | `OverworldMonsters` (Chebyshev: player within → IDLE→CHASING) |
| `LEASH_RANGE` | `8` | `OverworldMonsters` (Chebyshev: CHASING beyond home → RETURNING) |
| `DISPLAY_HEIGHT` | `2.0` | `CombatStage` (existing, shared for billboard height) |
| `MOVE_TIME` | `0.18` | `MonsterLayer` (move tween duration, feel only) |
| save `VERSION` | `11` | `SaveSerializer` |

## File Structure

**New:**
- `engine/world/overworld_monsters.gd` — `class_name OverworldMonsters extends RefCounted`. Pure state machine + BFS + range/contact + save serialization. No autoload deps.
- `presentation/world/monster_layer.gd` — `class_name MonsterLayer extends Node3D`. Overworld monster billboards, feet-on-floor, move tween.
- `tests/engine/world/test_overworld_monsters.gd` — full unit tests for the state machine.
- `tests/presentation/world/test_monster_layer.gd` — headless smoke tests.

**Modified:**
- `presentation/combat/combat_stage.gd` — `feet_offset` static + record `_feet_y` + place sprites at `_feet_y` (fix floating).
- `engine/save/save_data.gd` — add `monster_state` field.
- `autoload/game_state.gd` — add `monster_state` field.
- `autoload/save_system.gd` — capture/apply `monster_state`.
- `engine/save/save_serializer.gd` — `VERSION` 10→11 + `monster_state` (de)serialization.
- `presentation/world/main.gd` — wire layer + state machine; drive per step; contact→combat; victory removal; writeback.
- `tests/presentation/test_combat_stage.gd` — feet_offset tests + feet_y placement.
- `tests/engine/save/test_save_serializer.gd`, `..._statuses.gd`, `..._flags.gd`, `..._spells.gd`, `..._quests.gd` — version 10→11.
- `tests/engine/save/test_save_data.gd` — `monster_state` default/holds.

---

### Task 1: OverworldMonsters skeleton + constants + `cheb`

**Files:**
- Create: `engine/world/overworld_monsters.gd`
- Test: `tests/engine/world/test_overworld_monsters.gd`

**Interfaces:**
- Produces: `class_name OverworldMonsters extends RefCounted`; `const AGGRO_RANGE := 4`; `const LEASH_RANGE := 8`; `enum State { IDLE, CHASING, RETURNING }`; `var _list: Array`; `static func cheb(a: Vector2i, b: Vector2i) -> int`.

- [ ] **Step 1: Write the failing test**

Create `tests/engine/world/test_overworld_monsters.gd`:

```gdscript
extends GutTest

# ---- helpers (used by later tasks too) ----
func _open(_c: Vector2i) -> bool:
	return true

func _mk(uid: String, home: Vector2i, cell: Vector2i, state: int) -> Dictionary:
	return {"uid": uid, "group": "g", "home": home, "cell": cell, "state": state}

func _om(entries: Array) -> OverworldMonsters:
	var om := OverworldMonsters.new()
	om._list = entries
	return om

# ---- cheb ----
func test_cheb_diagonal_is_max_axis():
	assert_eq(OverworldMonsters.cheb(Vector2i(0, 0), Vector2i(3, 2)), 3)

func test_cheb_is_symmetric():
	assert_eq(OverworldMonsters.cheb(Vector2i(5, 1), Vector2i(2, 4)), 3)

func test_cheb_zero_for_same_cell():
	assert_eq(OverworldMonsters.cheb(Vector2i(2, 2), Vector2i(2, 2)), 0)

func test_constants():
	assert_eq(OverworldMonsters.AGGRO_RANGE, 4)
	assert_eq(OverworldMonsters.LEASH_RANGE, 8)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: FAIL — `OverworldMonsters` not found / parse error.

- [ ] **Step 3: Write minimal implementation**

Create `engine/world/overworld_monsters.gd`:

```gdscript
class_name OverworldMonsters
extends RefCounted

# 大地圖會走動的怪（MM3 風步進制）。純邏輯狀態機：玩家走一步 → step() 驅動範圍內的怪走一步。
# 不依賴 autoload：is_passable / is_defeated 皆由呼叫端注入；位置回寫存檔由 main.gd 負責。
const AGGRO_RANGE := 4   # Chebyshev：玩家進此範圍 → IDLE→CHASING
const LEASH_RANGE := 8   # Chebyshev：CHASING 離 home 超過此距離 → RETURNING（放棄）
enum State { IDLE, CHASING, RETURNING }

var _list: Array = []   # 每隻 { uid:String, group:String, home:Vector2i, cell:Vector2i, state:int }

# Chebyshev 距離（八方等距）：max(|dx|, |dy|)。
static func cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))
```

- [ ] **Step 4: Generate the `.gd.uid` sidecars**

Run: `godot --headless --path . --import`
Expected: import completes; `engine/world/overworld_monsters.gd.uid` and `tests/engine/world/test_overworld_monsters.gd.uid` now exist.

- [ ] **Step 5: Run test to verify it passes**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add engine/world/overworld_monsters.gd engine/world/overworld_monsters.gd.uid tests/engine/world/test_overworld_monsters.gd tests/engine/world/test_overworld_monsters.gd.uid
git commit -m "feat(world): OverworldMonsters skeleton + cheb (TDD)"
```

---

### Task 2: `next_step` 4-direction BFS

**Files:**
- Modify: `engine/world/overworld_monsters.gd`
- Test: `tests/engine/world/test_overworld_monsters.gd`

**Interfaces:**
- Consumes: `OverworldMonsters` (Task 1).
- Produces: `static func next_step(from: Vector2i, goal: Vector2i, is_passable: Callable, occupied) -> Vector2i` (first step of shortest 4-dir path; `occupied` cells unwalkable; `goal` always a valid terminal even if not passable; no path → returns `from`). Helper `static func _as_set(occupied) -> Dictionary`.

- [ ] **Step 1: Write the failing test**

Append to `tests/engine/world/test_overworld_monsters.gd`:

```gdscript
# ---- next_step (BFS) ----
func _walls_passable(walls: Dictionary, w: int, h: int) -> Callable:
	return func(c: Vector2i) -> bool:
		return c.x >= 0 and c.x < w and c.y >= 0 and c.y < h and not walls.has(c)

func test_next_step_straight_line():
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(3, 0), Callable(self, "_open"), {})
	assert_eq(step, Vector2i(1, 0))

func test_next_step_from_equals_goal():
	var step := OverworldMonsters.next_step(Vector2i(2, 2), Vector2i(2, 2), Callable(self, "_open"), {})
	assert_eq(step, Vector2i(2, 2))

func test_next_step_around_wall():
	var pass := _walls_passable({Vector2i(1, 0): true}, 3, 3)
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(2, 0), pass, {})
	assert_eq(step, Vector2i(0, 1), "牆擋住直線 → 先往下繞")

func test_next_step_no_path_returns_from():
	var pass := _walls_passable({Vector2i(1, 0): true}, 3, 1)   # 單列走道，被牆封死
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(2, 0), pass, {})
	assert_eq(step, Vector2i(0, 0), "無路 → 原地不動")

func test_next_step_goal_terminal_even_if_not_passable():
	var pass := func(_c: Vector2i) -> bool: return false   # 任何格都不可踏
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(1, 0), pass, {})
	assert_eq(step, Vector2i(1, 0), "goal 一律可當終點（怪能踏上玩家格）")

func test_next_step_avoids_occupied():
	var occupied := {Vector2i(1, 0): true}
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(2, 0), Callable(self, "_open"), occupied)
	assert_ne(step, Vector2i(1, 0), "被占用的格不踏")

func test_next_step_occupied_as_array():
	var step := OverworldMonsters.next_step(Vector2i(0, 0), Vector2i(2, 0), Callable(self, "_open"), [Vector2i(1, 0)])
	assert_ne(step, Vector2i(1, 0), "occupied 可為 Array")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: FAIL — `next_step` not found.

- [ ] **Step 3: Write minimal implementation**

Append to `engine/world/overworld_monsters.gd`:

```gdscript
# 4 向 BFS 求 from→goal 最短路的「第一步」。occupied（Dictionary 或 Array of Vector2i）視為不可踏，
# 但 goal 一律可當終點（怪能踏上玩家格＝接觸）。無路或被堵 → 回 from（不動）。
static func next_step(from: Vector2i, goal: Vector2i, is_passable: Callable, occupied) -> Vector2i:
	if from == goal:
		return from
	var blocked := _as_set(occupied)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var came := {from: from}   # 每格記其來源格，用以回溯第一步
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			var node := cur
			while came[node] != from:
				node = came[node]
			return node
		for d in dirs:
			var nxt: Vector2i = cur + d
			if came.has(nxt):
				continue
			var walkable: bool = (nxt == goal) or (is_passable.call(nxt) and not blocked.has(nxt))
			if not walkable:
				continue
			came[nxt] = cur
			queue.append(nxt)
	return from

# occupied 統一成 set（Dictionary[Vector2i→true]）。
static func _as_set(occupied) -> Dictionary:
	if occupied is Dictionary:
		return occupied
	var out: Dictionary = {}
	if occupied is Array:
		for c in occupied:
			out[c] = true
	return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: PASS (all Task 1 + Task 2 tests).

- [ ] **Step 5: Commit**

```bash
git add engine/world/overworld_monsters.gd tests/engine/world/test_overworld_monsters.gd
git commit -m "feat(world): OverworldMonsters.next_step BFS pathing (TDD)"
```

---

### Task 3: Lifecycle — `init_from_map`, `live`, `home_of`, `remove`

**Files:**
- Modify: `engine/world/overworld_monsters.gd`
- Test: `tests/engine/world/test_overworld_monsters.gd`

**Interfaces:**
- Consumes: `OverworldMonsters` (Tasks 1–2); `MapData.encounters`, `MapData.get_encounter(cell)`, `MapData.get_encounter_uid(cell)`.
- Produces:
  - `func init_from_map(map: MapData, is_defeated: Callable) -> void`
  - `func live() -> Array` → `[{uid, group, cell, state}, ...]`
  - `func home_of(uid: String) -> Vector2i` (unknown → `Vector2i(-1, -1)`)
  - `func remove(uid: String) -> void`

- [ ] **Step 1: Write the failing test**

Append to `tests/engine/world/test_overworld_monsters.gd`:

```gdscript
# ---- lifecycle ----
func _map_with_encounters() -> MapData:
	var map := MapData.new()
	map.encounters = {Vector2i(2, 2): "g", Vector2i(5, 1): "o"}
	map.encounter_uids = {Vector2i(2, 2): "u-g", Vector2i(5, 1): "u-o"}
	return map

func _none_defeated(_uid: String) -> bool:
	return false

func test_init_from_map_brings_group_home_cell_idle():
	var om := OverworldMonsters.new()
	om.init_from_map(_map_with_encounters(), Callable(self, "_none_defeated"))
	var rows := om.live()
	assert_eq(rows.size(), 2)
	# 找出 u-g 那筆
	var g: Dictionary = {}
	for r in rows:
		if r["uid"] == "u-g":
			g = r
	assert_eq(g["group"], "g")
	assert_eq(g["cell"], Vector2i(2, 2))
	assert_eq(g["state"], OverworldMonsters.State.IDLE)
	assert_eq(om.home_of("u-g"), Vector2i(2, 2))

func test_init_from_map_excludes_defeated():
	var om := OverworldMonsters.new()
	var is_def := func(uid: String) -> bool: return uid == "u-o"
	om.init_from_map(_map_with_encounters(), is_def)
	var rows := om.live()
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["uid"], "u-g")

func test_live_has_no_home_key():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(1, 1), OverworldMonsters.State.IDLE)])
	var rows := om.live()
	assert_false(rows[0].has("home"), "live() 不外洩 home（呈現層不需要）")
	assert_true(rows[0].has("cell"))

func test_home_of_unknown_returns_sentinel():
	var om := _om([])
	assert_eq(om.home_of("nope"), Vector2i(-1, -1))

func test_remove_drops_monster():
	var om := _om([
		_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE),
		_mk("b", Vector2i(1, 0), Vector2i(1, 0), OverworldMonsters.State.IDLE),
	])
	om.remove("a")
	var rows := om.live()
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["uid"], "b")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: FAIL — `init_from_map` not found.

- [ ] **Step 3: Write minimal implementation**

Append to `engine/world/overworld_monsters.gd`:

```gdscript
# 從地圖 encounter 建立怪清單；已擊敗（is_defeated 注入）者跳過。每隻起始 home=cell=encounter 格、IDLE。
func init_from_map(map: MapData, is_defeated: Callable) -> void:
	_list.clear()
	for cell in map.encounters:
		var uid := map.get_encounter_uid(cell)
		if is_defeated.is_valid() and is_defeated.call(uid):
			continue
		_list.append({
			"uid": uid,
			"group": map.get_encounter(cell),
			"home": cell,
			"cell": cell,
			"state": State.IDLE,
		})

# 給呈現層用的快照（不含 home/內部欄位）。
func live() -> Array:
	var out: Array = []
	for m in _list:
		out.append({"uid": m["uid"], "group": m["group"], "cell": m["cell"], "state": m["state"]})
	return out

func home_of(uid: String) -> Vector2i:
	for m in _list:
		if m["uid"] == uid:
			return m["home"]
	return Vector2i(-1, -1)

func remove(uid: String) -> void:
	for i in range(_list.size() - 1, -1, -1):
		if _list[i]["uid"] == uid:
			_list.remove_at(i)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/world/overworld_monsters.gd tests/engine/world/test_overworld_monsters.gd
git commit -m "feat(world): OverworldMonsters lifecycle (init/live/home_of/remove) (TDD)"
```

---

### Task 4: `step()` state machine (aggro / leash / contact / occupancy)

**Files:**
- Modify: `engine/world/overworld_monsters.gd`
- Test: `tests/engine/world/test_overworld_monsters.gd`

**Interfaces:**
- Consumes: `OverworldMonsters` (Tasks 1–3); `cheb`, `next_step`.
- Produces: `func step(player_cell: Vector2i, is_passable: Callable) -> Dictionary` returning `{ "contact": String, "moved": Array }`. Private helpers `_step_one`, `_chase`, `_occupied_set`.

- [ ] **Step 1: Write the failing test**

Append to `tests/engine/world/test_overworld_monsters.gd`:

```gdscript
# ---- step() state machine ----
func test_step_aggro_at_range_4_starts_chasing():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE)])
	var res := om.step(Vector2i(4, 0), Callable(self, "_open"))
	var m := om.live()[0]
	assert_eq(m["state"], OverworldMonsters.State.CHASING, "距離 4 → 開始追")
	assert_eq(m["cell"], Vector2i(1, 0), "並朝玩家走一步")
	assert_eq(res["moved"], ["a"])

func test_step_no_aggro_at_range_5_stays_idle():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE)])
	var res := om.step(Vector2i(5, 0), Callable(self, "_open"))
	var m := om.live()[0]
	assert_eq(m["state"], OverworldMonsters.State.IDLE, "距離 5 不追")
	assert_eq(m["cell"], Vector2i(0, 0), "不動")
	assert_eq(res["moved"], [])

func test_step_chasing_approaches_player():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(2, 0), OverworldMonsters.State.CHASING)])
	om.step(Vector2i(6, 0), Callable(self, "_open"))
	assert_eq(om.live()[0]["cell"], Vector2i(3, 0), "CHASING 逼近一步")

func test_step_leash_beyond_8_returns_home():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(9, 0), OverworldMonsters.State.CHASING)])
	om.step(Vector2i(10, 0), Callable(self, "_open"))
	var m := om.live()[0]
	assert_eq(m["state"], OverworldMonsters.State.RETURNING, "離 home 9>8 → 放棄返家")
	assert_eq(m["cell"], Vector2i(8, 0), "本步改朝 home")

func test_step_returning_ignores_player():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(2, 0), OverworldMonsters.State.RETURNING)])
	om.step(Vector2i(3, 0), Callable(self, "_open"))   # 玩家就在旁邊
	var m := om.live()[0]
	assert_eq(m["state"], OverworldMonsters.State.RETURNING, "返家途中無視玩家")
	assert_eq(m["cell"], Vector2i(1, 0), "繼續朝 home 走")

func test_step_returning_reaches_home_becomes_idle():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(1, 0), OverworldMonsters.State.RETURNING)])
	om.step(Vector2i(9, 9), Callable(self, "_open"))
	var m := om.live()[0]
	assert_eq(m["cell"], Vector2i(0, 0))
	assert_eq(m["state"], OverworldMonsters.State.IDLE, "抵 home → IDLE")

func test_step_contact_player_walks_into_standing_monster():
	var om := _om([_mk("a", Vector2i(3, 3), Vector2i(3, 3), OverworldMonsters.State.IDLE)])
	var res := om.step(Vector2i(3, 3), Callable(self, "_open"))   # 玩家走進站怪
	assert_eq(res["contact"], "a")
	assert_eq(res["moved"], [], "即時接觸不移動任何怪")
	assert_eq(om.live()[0]["cell"], Vector2i(3, 3), "怪沒移動")

func test_step_contact_monster_walks_into_player():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(1, 0), OverworldMonsters.State.CHASING)])
	var res := om.step(Vector2i(2, 0), Callable(self, "_open"))
	assert_eq(res["contact"], "a", "怪走進玩家格 → 接觸")
	assert_true(res["moved"].has("a"))

func test_step_two_monsters_never_overlap():
	# 兩怪同時想往玩家走；占用更新確保不疊格。
	var om := _om([
		_mk("a", Vector2i(0, 1), Vector2i(0, 1), OverworldMonsters.State.CHASING),
		_mk("b", Vector2i(2, 1), Vector2i(2, 1), OverworldMonsters.State.CHASING),
	])
	var pass := _walls_passable({}, 3, 3)
	om.step(Vector2i(1, 0), pass)
	var rows := om.live()
	assert_ne(rows[0]["cell"], rows[1]["cell"], "兩怪不重疊")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: FAIL — `step` not found.

- [ ] **Step 3: Write minimal implementation**

Append to `engine/world/overworld_monsters.gd`:

```gdscript
# 玩家走一步 → 驅動範圍內的怪走一步（步進制）。回 { contact: uid_or_"", moved: [uid...] }。
# is_passable: func(cell:Vector2i)->bool（= in_bounds and is_walkable；占用由本函式內部處理）。
func step(player_cell: Vector2i, is_passable: Callable) -> Dictionary:
	# 1. 先判即時接觸：玩家剛走進站著的怪 → 不移動任何怪。
	for m in _list:
		if m["cell"] == player_cell:
			return {"contact": m["uid"], "moved": []}
	# 2. 逐隻跑狀態機並移動一步（依 _list 順序，確定性）。
	var occupied := _occupied_set()
	var moved: Array = []
	for m in _list:
		var before: Vector2i = m["cell"]
		_step_one(m, player_cell, is_passable, occupied)
		var after: Vector2i = m["cell"]
		if after != before:
			occupied.erase(before)   # 移走舊格、加入新格，避免後續怪疊上來
			occupied[after] = true
			moved.append(m["uid"])
	# 3. 移動後再判接觸：怪走進玩家。
	var contact := ""
	for m in _list:
		if m["cell"] == player_cell:
			contact = m["uid"]
			break
	return {"contact": contact, "moved": moved}

# 單隻狀態機一步（就地改 m["cell"]/m["state"]）。
func _step_one(m: Dictionary, player_cell: Vector2i, is_passable: Callable, occupied: Dictionary) -> void:
	match m["state"]:
		State.IDLE:
			if cheb(m["cell"], player_cell) <= AGGRO_RANGE:
				m["state"] = State.CHASING
				_chase(m, player_cell, is_passable, occupied)
		State.CHASING:
			_chase(m, player_cell, is_passable, occupied)
		State.RETURNING:
			m["cell"] = next_step(m["cell"], m["home"], is_passable, occupied)
			if m["cell"] == m["home"]:
				m["state"] = State.IDLE

func _chase(m: Dictionary, player_cell: Vector2i, is_passable: Callable, occupied: Dictionary) -> void:
	if cheb(m["cell"], m["home"]) > LEASH_RANGE:
		m["state"] = State.RETURNING
		m["cell"] = next_step(m["cell"], m["home"], is_passable, occupied)
		if m["cell"] == m["home"]:
			m["state"] = State.IDLE
		return
	m["cell"] = next_step(m["cell"], player_cell, is_passable, occupied)

func _occupied_set() -> Dictionary:
	var out: Dictionary = {}
	for m in _list:
		out[m["cell"]] = true
	return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/world/overworld_monsters.gd tests/engine/world/test_overworld_monsters.gd
git commit -m "feat(world): OverworldMonsters.step state machine (aggro/leash/contact/occupancy) (TDD)"
```

---

### Task 5: `to_save` / `apply_saved` round-trip

**Files:**
- Modify: `engine/world/overworld_monsters.gd`
- Test: `tests/engine/world/test_overworld_monsters.gd`

**Interfaces:**
- Consumes: `OverworldMonsters` (Tasks 1–4).
- Produces:
  - `func to_save() -> Dictionary` → `{ uid: {"cell": Vector2i, "state": int} }`
  - `func apply_saved(saved: Dictionary) -> void` (overwrite cell/state for matching uid; home unchanged; non-saved monsters keep init defaults).

- [ ] **Step 1: Write the failing test**

Append to `tests/engine/world/test_overworld_monsters.gd`:

```gdscript
# ---- to_save / apply_saved ----
func test_to_save_format():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(3, 4), OverworldMonsters.State.CHASING)])
	var saved := om.to_save()
	assert_true(saved.has("a"))
	assert_eq(saved["a"]["cell"], Vector2i(3, 4))
	assert_eq(saved["a"]["state"], OverworldMonsters.State.CHASING)

func test_apply_saved_overwrites_cell_and_state_keeps_home():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE)])
	om.apply_saved({"a": {"cell": Vector2i(5, 6), "state": OverworldMonsters.State.RETURNING}})
	var m := om.live()[0]
	assert_eq(m["cell"], Vector2i(5, 6))
	assert_eq(m["state"], OverworldMonsters.State.RETURNING)
	assert_eq(om.home_of("a"), Vector2i(0, 0), "home 不被覆寫")

func test_apply_saved_leaves_unlisted_at_defaults():
	var om := _om([_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE)])
	om.apply_saved({"other": {"cell": Vector2i(9, 9), "state": 1}})
	var m := om.live()[0]
	assert_eq(m["cell"], Vector2i(0, 0), "未在 saved 的怪維持預設")
	assert_eq(m["state"], OverworldMonsters.State.IDLE)

func test_save_roundtrip():
	var om := _om([
		_mk("a", Vector2i(0, 0), Vector2i(3, 1), OverworldMonsters.State.CHASING),
		_mk("b", Vector2i(4, 4), Vector2i(4, 4), OverworldMonsters.State.IDLE),
	])
	var saved := om.to_save()
	var om2 := _om([
		_mk("a", Vector2i(0, 0), Vector2i(0, 0), OverworldMonsters.State.IDLE),
		_mk("b", Vector2i(4, 4), Vector2i(4, 4), OverworldMonsters.State.IDLE),
	])
	om2.apply_saved(saved)
	var a := om2.live()[0]
	assert_eq(a["cell"], Vector2i(3, 1))
	assert_eq(a["state"], OverworldMonsters.State.CHASING)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: FAIL — `to_save` not found.

- [ ] **Step 3: Write minimal implementation**

Append to `engine/world/overworld_monsters.gd`:

```gdscript
# 回 { uid: {"cell": Vector2i, "state": int} }（給 GameState.monster_state[map_id]）。
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for m in _list:
		out[m["uid"]] = {"cell": m["cell"], "state": m["state"]}
	return out

# saved 形如 { uid: {"cell": Vector2i, "state": int} }；對相符 uid 覆寫 cell/state（home 不動）。
func apply_saved(saved: Dictionary) -> void:
	for m in _list:
		if saved.has(m["uid"]):
			var rec: Dictionary = saved[m["uid"]]
			m["cell"] = rec["cell"]
			m["state"] = int(rec["state"])
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_overworld_monsters.gd -gexit`
Expected: PASS (full `OverworldMonsters` suite).

- [ ] **Step 5: Commit**

```bash
git add engine/world/overworld_monsters.gd tests/engine/world/test_overworld_monsters.gd
git commit -m "feat(world): OverworldMonsters save round-trip (to_save/apply_saved) (TDD)"
```

---

### Task 6: CombatStage feet-on-floor (fix floating)

**Files:**
- Modify: `presentation/combat/combat_stage.gd`
- Test: `tests/presentation/test_combat_stage.gd`

**Interfaces:**
- Consumes: `CombatStage` (existing).
- Produces: `static func feet_offset(camera_eye_height: float, display_height: float) -> float`; `var _feet_y: float`; `setup()` records `_feet_y`; `rebuild()` places sprites at `_feet_y` instead of `0.0`.

- [ ] **Step 1: Write the failing test**

Append to `tests/presentation/test_combat_stage.gd`:

```gdscript
# ---- 腳貼地（修漂浮）----
func test_feet_offset_pure():
	assert_almost_eq(CombatStage.feet_offset(1.2, 2.0), -0.2, 0.0001, "眼高 1.2、顯示高 2.0 → 腳偏移 -0.2")

func test_feet_offset_zero_eye_height():
	assert_almost_eq(CombatStage.feet_offset(0.0, 2.0), 1.0, 0.0001, "眼高 0 → 中心抬到地板上方 1.0")

func test_setup_records_feet_y_from_camera():
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.position.y = 1.2
	var st := CombatStage.new()
	add_child_autofree(st)
	st.setup(cam)
	assert_almost_eq(st._feet_y, -0.2, 0.0001, "眼高 1.2 → _feet_y = -0.2")

func test_rebuild_places_sprite_at_feet_y():
	var a := _monster("A", 10)
	var st := _stage_with([a])   # 此 helper 相機在原點，_feet_y = 1.0
	var s: Sprite3D = st._sprites[a]
	assert_almost_eq(s.position.y, st._feet_y, 0.0001, "billboard 不再寫死 y=0.0（漂浮），改用 _feet_y")
	assert_almost_eq(st._base_pos[s].y, st._feet_y, 0.0001, "base_pos 以 _feet_y 為基準（idle/attack/hit 都對）")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected: FAIL — `feet_offset` not found / `_feet_y` not found.

- [ ] **Step 3: Write minimal implementation**

In `presentation/combat/combat_stage.gd`, add the `_feet_y` var after the `_tween` declaration (line 24):

```gdscript
var _feet_y: float = 0.0       # billboard 腳貼地的 y（setup 時依相機眼高算；rebuild 用它定位）
```

Replace `setup()` (lines 26-27):

```gdscript
func setup(camera: Camera3D) -> void:
	_camera = camera
	_feet_y = feet_offset(_camera.position.y, DISPLAY_HEIGHT)
```

In `rebuild()`, replace the sprite positioning line (line 42):

```gdscript
		s.position = Vector3(spread, _feet_y, -4.0)
```

Add this static helper next to `pixel_size_for` (after line 158):

```gdscript
# 純函式：billboard 腳貼地的相對 y。billboard 中心需在地板上方 display_height/2；
# 戰鬥 sprite 掛在相機下（相對座標），故相對 y = display_height/2 − 相機眼高。
static func feet_offset(camera_eye_height: float, display_height: float) -> float:
	return display_height / 2.0 - camera_eye_height
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected: PASS (existing + new tests; existing tests reference `_base_pos[s].y` relatively, so they still pass).

- [ ] **Step 5: Commit**

```bash
git add presentation/combat/combat_stage.gd tests/presentation/test_combat_stage.gd
git commit -m "fix(combat): billboard feet-on-floor via feet_offset (no more floating) (TDD)"
```

---

### Task 7: Save v11 — `monster_state` field + serialization

**Files:**
- Modify: `engine/save/save_data.gd`, `autoload/game_state.gd`, `autoload/save_system.gd`, `engine/save/save_serializer.gd`
- Test: `tests/engine/save/test_save_serializer.gd`, `test_save_data.gd`, `test_save_serializer_statuses.gd`, `test_save_serializer_flags.gd`, `test_save_serializer_spells.gd`, `test_save_serializer_quests.gd`

**Interfaces:**
- Consumes: existing save pipeline.
- Produces: `SaveData.monster_state: Dictionary`; `GameState.monster_state: Dictionary`; `SaveSerializer.VERSION == 11`; serialized key `"monster_state"` (`map_id → { uid → {"cell":[x,y], "state":int} }`); `_monster_state_to_dict` / `_monster_state_from_dict`.

- [ ] **Step 1: Write the failing test**

Append to `tests/engine/save/test_save_serializer.gd`:

```gdscript
func test_roundtrip_monster_state():
	var d := SaveData.new()
	d.monster_state = {
		"wild_ne": {
			"u1": {"cell": Vector2i(3, 4), "state": 1},
			"u2": {"cell": Vector2i(0, 0), "state": 0},
		},
	}
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(d))
	assert_not_null(back)
	assert_eq(back.monster_state["wild_ne"]["u1"]["cell"], Vector2i(3, 4))
	assert_eq(back.monster_state["wild_ne"]["u1"]["state"], 1)
	assert_eq(back.monster_state["wild_ne"]["u2"]["cell"], Vector2i(0, 0))
	assert_eq(back.monster_state["wild_ne"]["u2"]["state"], 0)

func test_monster_state_absent_is_empty():
	var raw := {"version": SaveSerializer.VERSION, "state": {"player_pos": [0, 0]}}
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back)
	assert_eq(back.monster_state, {})

func test_monster_state_malformed_cell_skipped():
	var raw := SaveSerializer.to_dict(_sample())
	raw["state"]["monster_state"] = {"wild_ne": {"u1": {"cell": [9], "state": 2}}}  # size<2 → 畸形
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back)
	assert_false(back.monster_state["wild_ne"].has("u1"), "畸形座標被略過")
```

Also update the version assertion in `tests/engine/save/test_save_serializer.gd` (lines 78-79):

```gdscript
func test_to_dict_version_is_11():
	assert_eq(SaveSerializer.to_dict(_sample())["version"], 11)
```

Update the version assertions in the other four save tests:
- `tests/engine/save/test_save_serializer_statuses.gd` lines 35-37:
  ```gdscript
  func test_version_is_11():
  	assert_eq(SaveSerializer.VERSION, 11)
  	assert_eq(SaveSerializer.to_dict(_party_data())["version"], 11)
  ```
- `tests/engine/save/test_save_serializer_flags.gd` lines 11-12:
  ```gdscript
  func test_version_is_11():
  	assert_eq(SaveSerializer.to_dict(_data())["version"], 11)
  ```
- `tests/engine/save/test_save_serializer_spells.gd` lines 15-16:
  ```gdscript
  func test_version_is_11():
  	assert_eq(SaveSerializer.to_dict(_sample())["version"], 11)
  ```
- `tests/engine/save/test_save_serializer_quests.gd` lines 45-46:
  ```gdscript
  func test_version_is_11():
  	assert_eq(SaveSerializer.to_dict(_data())["version"], 11)
  ```

Append to `tests/engine/save/test_save_data.gd`:

```gdscript
func test_monster_state_defaults_empty_and_holds():
	var d := SaveData.new()
	assert_eq(d.monster_state.size(), 0)
	d.monster_state = {"m": {"u": {"cell": Vector2i(1, 2), "state": 1}}}
	assert_eq(d.monster_state["m"]["u"]["cell"], Vector2i(1, 2))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_save_serializer.gd -gexit`
Expected: FAIL — version assertion expects 11 (still 10); `monster_state` not found.

- [ ] **Step 3a: SaveData field**

In `engine/save/save_data.gd`, add after `defeated_encounters` (line 16):

```gdscript
var monster_state: Dictionary = {}  # String map_id -> { uid -> {"cell": Vector2i, "state": int} }（大地圖怪位置/狀態）
```

- [ ] **Step 3b: GameState field**

In `autoload/game_state.gd`, add after `defeated_encounters` (line 20):

```gdscript
var monster_state: Dictionary = {}   # String map_id -> { uid -> {"cell": Vector2i, "state": int} }（持久；大地圖怪位置/狀態）
```

- [ ] **Step 3c: SaveSystem capture/apply**

In `autoload/save_system.gd`, add to `capture_from` after line 73 (`data.defeated_encounters = gs.defeated_encounters`):

```gdscript
	data.monster_state = gs.monster_state
```

And in `apply_to` after line 90 (`gs.defeated_encounters = data.defeated_encounters`):

```gdscript
	gs.monster_state = data.monster_state
```

- [ ] **Step 3d: SaveSerializer version + serialization**

In `engine/save/save_serializer.gd`:

Bump `VERSION` (line 4):

```gdscript
const VERSION := 11
```

In `to_dict`'s `state` dict, add after the `defeated_encounters` line (line 24):

```gdscript
			"monster_state": _monster_state_to_dict(data.monster_state),
```

In `from_dict`, add after the `defeated_encounters` line (line 54):

```gdscript
	data.monster_state = _monster_state_from_dict(s.get("monster_state", {}))
```

Add these helpers in the `--- internal ---` section (e.g. after `_cleared_from_dict`, line 186):

```gdscript
static func _monster_state_to_dict(ms: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id in ms:
		var inner: Dictionary = {}
		for uid in ms[map_id]:
			var rec: Dictionary = ms[map_id][uid]
			inner[uid] = {"cell": _vec(rec["cell"]), "state": int(rec["state"])}
		out[map_id] = inner
	return out

static func _monster_state_from_dict(raw) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for map_id in raw:
		var rec_map = raw[map_id]
		if typeof(rec_map) != TYPE_DICTIONARY:
			continue
		var inner: Dictionary = {}
		for uid in rec_map:
			var rec = rec_map[uid]
			if typeof(rec) != TYPE_DICTIONARY:
				continue
			var c = rec.get("cell", null)
			if not _is_vec_shape(c):
				continue
			inner[String(uid)] = {"cell": _to_vec(c), "state": int(rec.get("state", 0))}
		out[String(map_id)] = inner
	return out
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_save_serializer.gd -gexit`
Then the other touched files:
`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_save_data.gd -gexit`
And re-run statuses/flags/spells/quests via the full suite later. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/save/save_data.gd autoload/game_state.gd autoload/save_system.gd engine/save/save_serializer.gd tests/engine/save/
git commit -m "feat(save): v11 monster_state (overworld monster positions persist) (TDD)"
```

---

### Task 8: MonsterLayer — overworld billboards (feet-on-floor + move tween)

**Files:**
- Create: `presentation/world/monster_layer.gd`
- Test: `tests/presentation/world/test_monster_layer.gd`

**Interfaces:**
- Consumes: `live()` rows `{uid, group, cell, state}` (Task 3); `CombatStage.pixel_size_for`, `CombatStage.DISPLAY_HEIGHT`; `Bestiary.group_defs_for`; `MonsterSpriteCatalog.textures_for`; `GridGeometry.cell_to_world`.
- Produces: `class_name MonsterLayer extends Node3D`; `func rebuild(monsters: Array) -> void`; `func apply_moves(monsters: Array) -> void`; `var _sprites: Dictionary` (uid → Sprite3D); `const MOVE_TIME := 0.18`.

- [ ] **Step 1: Write the failing test**

Create `tests/presentation/world/test_monster_layer.gd`:

```gdscript
extends GutTest

func _layer() -> MonsterLayer:
	var l := MonsterLayer.new()
	add_child_autofree(l)
	return l

func _live(uid: String, cell: Vector2i) -> Dictionary:
	return {"uid": uid, "group": "g", "cell": cell, "state": 0}

func test_rebuild_one_sprite_per_monster():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(1, 1)), _live("u2", Vector2i(2, 3))])
	assert_eq(l._sprites.size(), 2)

func test_rebuild_places_billboard_feet_on_floor():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(1, 1))])
	var s: Sprite3D = l._sprites["u1"]
	assert_almost_eq(s.position.y, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0001, "中心在地板上方 DISPLAY_HEIGHT/2（腳貼地）")
	var w := GridGeometry.cell_to_world(Vector2i(1, 1))
	assert_almost_eq(s.position.x, w.x, 0.0001)
	assert_almost_eq(s.position.z, w.z, 0.0001)

func test_rebuild_uses_billboard_and_normalized_size():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0))])
	var s: Sprite3D = l._sprites["u1"]
	assert_eq(s.billboard, BaseMaterial3D.BILLBOARD_ENABLED)
	assert_almost_eq(s.pixel_size, CombatStage.pixel_size_for(s.texture, CombatStage.DISPLAY_HEIGHT), 0.0001, "尺寸與戰鬥一致")

func test_rebuild_clears_previous():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0)), _live("u2", Vector2i(1, 0))])
	l.rebuild([_live("u3", Vector2i(2, 0))])
	assert_eq(l._sprites.size(), 1)
	assert_true(l._sprites.has("u3"))

func test_apply_moves_no_crash_and_keeps_count():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0))])
	l.apply_moves([_live("u1", Vector2i(1, 0))])   # 觸發補間，不 crash
	assert_eq(l._sprites.size(), 1)

func test_goblin_group_uses_idle_texture():
	var l := _layer()
	l.rebuild([{"uid": "g1", "group": "g", "cell": Vector2i(0, 0), "state": 0}])
	var s: Sprite3D = l._sprites["g1"]
	var idle: Texture2D = MonsterSpriteCatalog.textures_for("goblin")["idle"]
	assert_eq(s.texture, idle, "哥布林群組（g→goblin.tres，id=goblin）代表用 idle 真圖")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_monster_layer.gd -gexit`
Expected: FAIL — `MonsterLayer` not found.

- [ ] **Step 3: Write minimal implementation**

Create `presentation/world/monster_layer.gd`:

```gdscript
class_name MonsterLayer
extends Node3D

# 大地圖會走動的怪 billboard 層。鏡射 ObjectLayer/ChestLayer：跟著切地圖由 main.gd rebuild。
# 腳貼地與尺寸共用 CombatStage 的常數/static，確保和戰鬥裡同大小、同腳踩地板。
const MOVE_TIME := 0.18   # 移動補間時長（對齊玩家步速 feel；不像素測）

var _sprites: Dictionary = {}   # uid -> Sprite3D

func rebuild(monsters: Array) -> void:
	_clear()
	for m in monsters:
		var s := Sprite3D.new()
		var tex := _texture_for(m["group"])
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture = tex
		s.pixel_size = CombatStage.pixel_size_for(tex, CombatStage.DISPLAY_HEIGHT)
		s.position = _world_pos(m["cell"])
		add_child(s)
		_sprites[m["uid"]] = s

func apply_moves(monsters: Array) -> void:
	for m in monsters:
		var uid: String = m["uid"]
		if not _sprites.has(uid):
			continue
		var s: Sprite3D = _sprites[uid]
		var target := _world_pos(m["cell"])
		if s.position.is_equal_approx(target):
			continue
		var tw := create_tween()
		tw.tween_property(s, "position", target, MOVE_TIME)

func _world_pos(cell: Vector2i) -> Vector3:
	return GridGeometry.cell_to_world(cell) + Vector3(0.0, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0)

# 代表貼圖：群組第 0 隻的 idle 真圖；缺則純色 placeholder（其餘怪暫無真圖）。
func _texture_for(group_key: String) -> Texture2D:
	var defs := Bestiary.group_defs_for(group_key)
	if not defs.is_empty():
		var tex = MonsterSpriteCatalog.textures_for(defs[0].id)["idle"]
		if tex != null:
			return tex
	return _placeholder(Color(0.8, 0.3, 0.3))

func _placeholder(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_sprites.clear()
```

- [ ] **Step 4: Generate the `.gd.uid` sidecars**

Run: `godot --headless --path . --import`
Expected: `presentation/world/monster_layer.gd.uid` and `tests/presentation/world/test_monster_layer.gd.uid` exist.

- [ ] **Step 5: Run test to verify it passes**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_monster_layer.gd -gexit`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add presentation/world/monster_layer.gd presentation/world/monster_layer.gd.uid tests/presentation/world/test_monster_layer.gd tests/presentation/world/test_monster_layer.gd.uid
git commit -m "feat(world): MonsterLayer overworld billboards (feet-on-floor + move tween) (TDD)"
```

---

### Task 9: Wire into main.gd (drive per step, contact→combat, victory removal, writeback)

**Files:**
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes: `OverworldMonsters` (Tasks 1–5), `MonsterLayer` (Task 8), `GameState.monster_state` (Task 7), `MapManager.current_map`/`current_grid`, existing `_start_combat`, `_on_combat_finished`.
- Produces (private): `var _overworld_monsters`, `var _monster_layer`, `var _combat_uid`; `func _rebuild_monsters_for_current_map()`; `func _is_passable(cell)`; `func _start_combat_for_uid(uid)`.

> **Note:** the spec lists three map-enter rebuild points (`_ready`, `_enter_via_link`, `_on_edge_exit_attempted`); this codebase has a **fourth** — `_on_loaded` (line 465) rebuilds the world after a load. Monster init must run there too, or loaded `monster_state` is never applied. We factor a single helper and call it from all four.

- [ ] **Step 1: Add member vars**

In `presentation/world/main.gd`, add after `var _world_renderer: WorldStitchRenderer` (line 19):

```gdscript
var _overworld_monsters: OverworldMonsters
var _monster_layer: MonsterLayer
var _combat_uid: String = ""
```

- [ ] **Step 2: Add helpers**

Add these methods near `_start_combat` (e.g. after `_set_overworld_hud_visible`, around line 246):

```gdscript
func _rebuild_monsters_for_current_map() -> void:
	var map := MapManager.current_map
	_overworld_monsters = OverworldMonsters.new()
	_overworld_monsters.init_from_map(map, Callable(GameState, "is_defeated"))
	_overworld_monsters.apply_saved(GameState.monster_state.get(map.map_id, {}))
	_monster_layer.rebuild(_overworld_monsters.live())

func _is_passable(cell: Vector2i) -> bool:
	return MapManager.current_grid.is_walkable(cell)   # is_walkable 已含 in_bounds

func _start_combat_for_uid(uid: String) -> void:
	_combat_uid = uid
	_start_combat(_overworld_monsters.home_of(uid))   # 戰鬥身分錨在 home 格（MapData 仍持有 group/uid）
```

- [ ] **Step 3: Create the layer + init at startup (`_ready`)**

In `_ready`, after `_world_renderer.rebuild(MapManager.current_map)` (line 45), add:

```gdscript
	_monster_layer = MonsterLayer.new()
	add_child(_monster_layer)
	_rebuild_monsters_for_current_map()
```

- [ ] **Step 4: Re-init at the three other map-enter points**

- In `_enter_via_link`, after `_world_renderer.rebuild(MapManager.current_map)` (line 189), add: `	_rebuild_monsters_for_current_map()`
- In `_on_edge_exit_attempted`, after `_world_renderer.rebuild(MapManager.current_map)` (line 216), add: `	_rebuild_monsters_for_current_map()`
- In `_on_loaded`, after `_world_renderer.refresh_objects(MapManager.current_map)` (line 469), add: `	_rebuild_monsters_for_current_map()`

- [ ] **Step 5: Replace the encounter trigger in `_on_entered_cell`**

In `_on_entered_cell`, replace the block (lines 144-146):

```gdscript
	if MapManager.current_map.has_encounter(pos):
		_start_combat(pos)
		return
```

with:

```gdscript
	var res := _overworld_monsters.step(pos, Callable(self, "_is_passable"))
	_monster_layer.apply_moves(_overworld_monsters.live())
	GameState.monster_state[GameState.current_map_id] = _overworld_monsters.to_save()   # 每步回寫（S/L 正確）
	if res["contact"] != "":
		_start_combat_for_uid(res["contact"])
		return
```

- [ ] **Step 6: Victory removal + writeback (`_on_combat_finished`)**

In `_on_combat_finished`, in the `VICTORY` branch, after `GameState.mark_encounter_cleared(MapManager.current_map.map_id, _combat_pos)` (line 258), add:

```gdscript
		_overworld_monsters.remove(_combat_uid)
		_monster_layer.rebuild(_overworld_monsters.live())
		GameState.monster_state[MapManager.current_map.map_id] = _overworld_monsters.to_save()
```

- [ ] **Step 7: Headless boot smoke (no SCRIPT ERROR)**

Run: `godot --headless --path . --quit 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|error" || echo "BOOT CLEAN"`
Expected: `BOOT CLEAN` (no script/parse errors loading the project + autoloads).

Then launch the main scene briefly to confirm `main.gd` parses and `_ready` runs without runtime errors:

Run: `./run.sh --headless --quit-after 5 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" || echo "MAIN SCENE CLEAN"`
Expected: `MAIN SCENE CLEAN`.

- [ ] **Step 8: Full suite green**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all tests pass (previous total + new `OverworldMonsters`/`MonsterLayer`/save tests; 0 failures).

- [ ] **Step 9: Commit**

```bash
git add presentation/world/main.gd
git commit -m "feat(world): wire OverworldMonsters+MonsterLayer into main (roam/contact/victory/save)"
```

---

## Manual Visual Gate (after all tasks; human-run)

These can't be unit-tested; run them by hand with `./run.sh`:
- Boot → start map (`wild_nw`) shows monster billboards standing on the floor (not floating), correct size.
- Walk toward a monster within 4 cells → it starts stepping toward you each step you take.
- Lead it >8 cells from its home → it turns back toward home (RETURNING) and ignores you.
- Let it reach you (or walk into it) → combat starts; win → that monster is gone from the map.
- Combat: the goblin sprite stands feet-on-floor (the float bug is fixed) and matches the overworld size.
- Save mid-chase, reload → monsters resume at their saved cells/states.
- Fast path to see goblins: walk northeast to `wild_ne` (goblin encounter, HP raised for observation).

## Self-Review

**1. Spec coverage** — every spec section maps to a task:
- `OverworldMonsters` class/constants/state machine/BFS/contact/save → Tasks 1–5.
- `CombatStage` feet fix → Task 6.
- Save v11 (`SaveData`/`GameState`/`SaveSystem`/`SaveSerializer` + test data) → Task 7.
- `MonsterLayer` billboards feet-on-floor + tween → Task 8.
- `main.gd` wiring (init at map-enter, per-step drive, contact→`_start_combat(home)`, victory removal, per-step writeback) → Task 9.
- Shared feet/size anchor (`DISPLAY_HEIGHT`, `pixel_size_for`) used by both `CombatStage` and `MonsterLayer` → Tasks 6 + 8.
- Test strategy (full unit for `OverworldMonsters`; smoke for `MonsterLayer`; pure `feet_offset`; save round-trip; headless boot) → Tasks 1–9.

**2. Placeholder scan** — no TBD/TODO; every code step shows complete code; commands have expected output.

**3. Type consistency** — `live()` rows use keys `{uid, group, cell, state}` consistently across Tasks 3/8/9; `step()` returns `{contact, moved}` consumed in Task 9; `to_save()` shape `{uid:{cell,state}}` matches `_monster_state_to_dict` and `apply_saved` in Tasks 5/7; `home_of` consumed by `_start_combat_for_uid`. `_feet_y`/`feet_offset` names consistent across Task 6.
