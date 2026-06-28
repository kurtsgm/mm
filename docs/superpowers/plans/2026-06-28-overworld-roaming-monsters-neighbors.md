# 大地圖鄰圖怪物顯示（stitch 周邊區）Implementation Plan（addendum）

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Render monsters from NEIGHBORING stitched maps as static idle billboards (so the seamless world shows monsters beyond the current map). Only the current map's monsters move/chase (unchanged); neighbor monsters activate when the player enters their map.

**Architecture:** A pure `NeighborMonsters.collect(...)` helper aggregates every non-current stitched region's undefeated monsters into global-cell display rows (reusing `WorldStitch.place` for region offsets, `OverworldMonsters` for per-map defeated-filtering + saved-position restore). A second `MonsterLayer` instance (`_neighbor_monster_layer`) renders those rows — `MonsterLayer.rebuild` already draws a `{uid, group, cell}` list at global `cell_to_world`, so no presentation changes are needed. Wired in `main.gd` alongside the existing current-map layer at the same map-enter rebuild points.

**Tech Stack:** Godot 4.7 (GDScript), GUT.

## Global Constraints

- Godot binary `godot` on PATH (4.7).
- New `class_name` `.gd` → run `godot --headless --path . --import` to generate `.gd.uid`, commit both (source + test).
- GDScript 4.7: never `:=` on a Variant rvalue (use explicit type annotations).
- Single-file test: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<file>.gd -gexit`. Full suite: drop `-gselect`.
- Branch `feat/overworld-roaming-monsters`; verify branch before each commit; `git add` only this task's files.
- Reuse existing infra — do NOT modify `WorldStitch`, `OverworldMonsters`, or `MonsterLayer` (they already do what's needed). Neighbor monsters are STATIC (no movement/chase).

## Facts (verified)

- `WorldStitch.place(origin_map: MapData, loader: Callable, half: int, center: Vector2i) -> Array` → `[{ "map": MapData, "ox": int, "oy": int }, ...]` (cell-space offsets; origin included at ox=oy=0; view-window culled). No side effects. `WorldStitchRenderer` calls it with `half = max(current_map.width, current_map.height)`, `center = Vector2i(current_map.width/2, current_map.height/2)`.
- `MapManager.peek_map(id) -> MapData` loads a map with no side effects (returns null if missing).
- `OverworldMonsters.init_from_map(map, is_defeated)` (skips defeated), `apply_saved(saved)` (restores cell/state), `live() -> [{uid, group, cell, state}, ...]` (cell in LOCAL coords).
- `GridGeometry.cell_to_world(C)` is additive: a monster at local cell `C` in a region with cell-offset `O` renders at global cell `C + O`.
- `MonsterLayer.rebuild(rows)` draws each row `{uid, group, cell}` at `cell_to_world(cell) + Vector3(0, DISPLAY_HEIGHT/2, 0)`, billboard, size via `CombatStage.pixel_size_for`. It's a plain Node3D added to `main` (global coords). A second instance is independent (`_sprites` keyed by uid; neighbor uids differ from current-map uids).
- `main.gd`: `_rebuild_monsters_for_current_map()` (helper) is called at all four map-enter points (`_ready`, `_enter_via_link`, `_on_edge_exit_attempted`, `_on_loaded`); the victory branch calls `_monster_layer.rebuild(...)` directly. `GameState.monster_state` is `map_id → {uid → {cell, state}}`.

---

### Task 1: `NeighborMonsters.collect` pure helper

**Files:**
- Create: `engine/world/neighbor_monsters.gd`
- Test: `tests/engine/world/test_neighbor_monsters.gd`

**Interfaces:**
- Produces: `class_name NeighborMonsters extends Object`; `static func collect(current_map: MapData, loader: Callable, is_defeated: Callable, saved_provider: Callable) -> Array` → returns `[{ "uid": String, "group": String, "cell": Vector2i (GLOBAL), "state": int }, ...]` for every stitched region whose `map_id != current_map.map_id`. `loader` = `func(map_id) -> MapData` (peek). `is_defeated` = `func(uid) -> bool`. `saved_provider` = `func(map_id) -> Dictionary` (monster_state for that map; may return non-Dictionary → treated as empty).

- [ ] **Step 1: Write the failing test**

Create `tests/engine/world/test_neighbor_monsters.gd`:

```gdscript
extends GutTest

# 建一張地圖（含 encounters + 鄰接），mirror test_world_stitch.gd 風格。
func _map(id: String, w: int, h: int, neighbors: Dictionary, encs: Dictionary, uids: Dictionary) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.neighbors = neighbors
	m.encounters = encs
	m.encounter_uids = uids
	return m

var _world: Dictionary = {}

func _loader(id: String) -> MapData:
	return _world.get(id, null)

func _none_defeated(_uid: String) -> bool:
	return false

func _no_saved(_map_id: String) -> Dictionary:
	return {}

func test_collect_includes_east_neighbor_at_global_offset():
	# a(5x5) 東接 e(5x5)；e 在 (1,2) 有一隻怪 → 全域格 = (1+5, 2) = (6,2)。
	var a := _map("a", 5, 5, {GridDirection.Dir.EAST: "e"}, {}, {})
	var e := _map("e", 5, 5, {GridDirection.Dir.WEST: "a"}, {Vector2i(1, 2): "g"}, {Vector2i(1, 2): "u-e"})
	_world = {"a": a, "e": e}
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), Callable(self, "_none_defeated"), Callable(self, "_no_saved"))
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["uid"], "u-e")
	assert_eq(rows[0]["group"], "g")
	assert_eq(rows[0]["cell"], Vector2i(6, 2), "鄰圖怪以全域 cell 偏移呈現")

func test_collect_excludes_current_map_monsters():
	# a 自己有怪；collect 不該含 a（current 由別的層畫）。
	var a := _map("a", 5, 5, {GridDirection.Dir.EAST: "e"}, {Vector2i(0, 0): "g"}, {Vector2i(0, 0): "u-a"})
	var e := _map("e", 5, 5, {GridDirection.Dir.WEST: "a"}, {Vector2i(0, 0): "g"}, {Vector2i(0, 0): "u-e"})
	_world = {"a": a, "e": e}
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), Callable(self, "_none_defeated"), Callable(self, "_no_saved"))
	var uids: Array = []
	for r in rows:
		uids.append(r["uid"])
	assert_false(uids.has("u-a"), "current map 的怪不在 neighbor 清單")
	assert_true(uids.has("u-e"))

func test_collect_excludes_defeated():
	var a := _map("a", 5, 5, {GridDirection.Dir.EAST: "e"}, {}, {})
	var e := _map("e", 5, 5, {GridDirection.Dir.WEST: "a"}, {Vector2i(1, 1): "g"}, {Vector2i(1, 1): "u-e"})
	_world = {"a": a, "e": e}
	var is_def := func(uid: String) -> bool: return uid == "u-e"
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), is_def, Callable(self, "_no_saved"))
	assert_eq(rows.size(), 0, "已擊敗的鄰圖怪不顯示")

func test_collect_applies_saved_position():
	# e 的怪存檔已移動到 (3,3) → 全域 = (3+5, 3) = (8,3)。
	var a := _map("a", 5, 5, {GridDirection.Dir.EAST: "e"}, {}, {})
	var e := _map("e", 5, 5, {GridDirection.Dir.WEST: "a"}, {Vector2i(1, 1): "g"}, {Vector2i(1, 1): "u-e"})
	_world = {"a": a, "e": e}
	var saved := func(map_id: String) -> Dictionary:
		if map_id == "e":
			return {"u-e": {"cell": Vector2i(3, 3), "state": 1}}
		return {}
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), Callable(self, "_none_defeated"), saved)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["cell"], Vector2i(8, 3), "套用存檔位置後再加全域偏移")

func test_collect_handles_non_dictionary_saved():
	# saved_provider 回非 Dictionary（如 null）時不 crash，當空處理。
	var a := _map("a", 5, 5, {GridDirection.Dir.EAST: "e"}, {}, {})
	var e := _map("e", 5, 5, {GridDirection.Dir.WEST: "a"}, {Vector2i(0, 0): "g"}, {Vector2i(0, 0): "u-e"})
	_world = {"a": a, "e": e}
	var bad := func(_map_id: String): return null
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), Callable(self, "_none_defeated"), bad)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["cell"], Vector2i(0, 0), "non-Dictionary saved → 當空、用 home 格")

func test_collect_no_neighbors_returns_empty():
	var a := _map("a", 5, 5, {}, {Vector2i(0, 0): "g"}, {Vector2i(0, 0): "u-a"})
	_world = {"a": a}
	var rows := NeighborMonsters.collect(a, Callable(self, "_loader"), Callable(self, "_none_defeated"), Callable(self, "_no_saved"))
	assert_eq(rows.size(), 0, "無鄰圖 → 空")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_neighbor_monsters.gd -gexit`
Expected: FAIL — `NeighborMonsters` not declared.

- [ ] **Step 3: Write minimal implementation**

Create `engine/world/neighbor_monsters.gd`:

```gdscript
class_name NeighborMonsters
extends Object

# 蒐集「鄰接拼接地圖」的怪，回全域 cell 的靜態顯示列（current map 的怪由 _monster_layer 另畫）。
# 純邏輯：loader/is_defeated/saved_provider 皆注入。movement 不在此（鄰圖怪只顯示、不追）。
# 重用 WorldStitch（區域偏移）+ OverworldMonsters（排除 defeated、套存檔位置、live 格式）。
static func collect(current_map: MapData, loader: Callable, is_defeated: Callable, saved_provider: Callable) -> Array:
	var out: Array = []
	if current_map == null:
		return out
	var half: int = max(current_map.width, current_map.height)
	var center := Vector2i(current_map.width / 2, current_map.height / 2)
	var placed := WorldStitch.place(current_map, loader, half, center)
	for region in placed:
		var m: MapData = region["map"]
		if m == null or m.map_id == current_map.map_id:
			continue   # current map 的怪由別的層畫
		var offset := Vector2i(int(region["ox"]), int(region["oy"]))
		var om := OverworldMonsters.new()
		om.init_from_map(m, is_defeated)
		var saved = saved_provider.call(m.map_id)
		if typeof(saved) != TYPE_DICTIONARY:
			saved = {}
		om.apply_saved(saved)
		for row in om.live():
			out.append({
				"uid": row["uid"],
				"group": row["group"],
				"cell": row["cell"] + offset,
				"state": row["state"],
			})
	return out
```

- [ ] **Step 4: Generate `.gd.uid`**

Run: `godot --headless --path . --import`
Expected: `engine/world/neighbor_monsters.gd.uid` and `tests/engine/world/test_neighbor_monsters.gd.uid` exist.

- [ ] **Step 5: Run test to verify it passes**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_neighbor_monsters.gd -gexit`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add engine/world/neighbor_monsters.gd engine/world/neighbor_monsters.gd.uid tests/engine/world/test_neighbor_monsters.gd tests/engine/world/test_neighbor_monsters.gd.uid
git commit -m "feat(world): NeighborMonsters.collect — neighbor-map monster display rows (TDD)"
```

---

### Task 2: Wire neighbor monster layer into main.gd

**Files:**
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes: `NeighborMonsters.collect` (Task 1), existing `MonsterLayer`, `MapManager.peek_map`, `GameState.is_defeated`, `GameState.monster_state`.
- Produces (private): `var _neighbor_monster_layer: MonsterLayer`; `func _saved_monster_state(map_id) -> Dictionary`.

- [ ] **Step 1: Add member var**

In `presentation/world/main.gd`, after `var _monster_layer: MonsterLayer`:

```gdscript
var _neighbor_monster_layer: MonsterLayer
```

- [ ] **Step 2: Create the neighbor layer in `_ready`**

In `_ready`, right after the existing `_monster_layer` creation block (`_monster_layer = MonsterLayer.new()` / `add_child(_monster_layer)`), and BEFORE `_rebuild_monsters_for_current_map()`:

```gdscript
	_neighbor_monster_layer = MonsterLayer.new()
	add_child(_neighbor_monster_layer)
```

(So both layers exist before the first `_rebuild_monsters_for_current_map()` call.)

- [ ] **Step 3: Add the saved-state provider helper + collect neighbors in the rebuild helper**

Add this helper near `_rebuild_monsters_for_current_map` (e.g. just below it):

```gdscript
func _saved_monster_state(map_id) -> Dictionary:
	return GameState.monster_state.get(map_id, {})
```

In `_rebuild_monsters_for_current_map`, after the existing `_monster_layer.rebuild(_overworld_monsters.live())` line, append:

```gdscript
	var neighbors := NeighborMonsters.collect(map, Callable(MapManager, "peek_map"), Callable(GameState, "is_defeated"), Callable(self, "_saved_monster_state"))
	_neighbor_monster_layer.rebuild(neighbors)
```

(`map` is the local `var map := MapManager.current_map` already declared at the top of the helper. `neighbors` is typed `Array` from `collect`, so `:=` is fine.)

- [ ] **Step 4: Full suite + headless boot smoke**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green (Task 1 added 6 tests; this task adds none → same count as after Task 1).

Run: `godot --headless --path . --quit 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" || echo BOOT_CLEAN`
Expected: `BOOT_CLEAN`.

Run: `./run.sh --headless --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|Parse Error" || echo MAIN_SCENE_CLEAN`
Expected: `MAIN_SCENE_CLEAN`.

- [ ] **Step 5: Commit**

```bash
git add presentation/world/main.gd
git commit -m "feat(world): render neighbor-map monsters via second MonsterLayer (static display)"
```

---

## Manual Visual Gate (human-run `./run.sh`)
- Stand near a map edge (e.g. in `wild_nw` near the east/south border) → monsters belonging to the adjacent map now appear across the seam, feet on floor, correct size.
- Cross into that map → those monsters become active (chase within aggro 4); the next ring of neighbors now shows.
- Defeated neighbor monsters do not reappear across the seam; a neighbor monster you previously moved shows at its saved position.

## Self-Review
- Spec coverage: neighbor display via pure `collect` (Task 1) + second layer wiring (Task 2). Movement stays current-map-only (unchanged). ✓
- No changes to `WorldStitch`/`OverworldMonsters`/`MonsterLayer` (pure reuse). ✓
- Types: `collect` returns `{uid, group, cell, state}` rows (same shape `MonsterLayer.rebuild` consumes). ✓
- No `:=` on Variant rvalue (`var saved = saved_provider.call(...)` uses plain `=`). ✓
