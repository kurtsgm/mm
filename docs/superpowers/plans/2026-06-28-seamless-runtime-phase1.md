# Seamless Runtime Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 wild 地圖的離散邊界切換換成「統一可遊玩 grid + 玩家無縫連續移動」；建立全域 cell ↔ (map_id, local) 反查與合併 passability 的基礎層 `WorldGrid`。

**Architecture:** 新增純邏輯 `WorldGrid`（RefCounted），由焦點圖 + `peek_map` loader 經 `WorldStitch.place` 拼成 3×3 統一 grid，提供 `is_walkable(global)` 與 `resolve(global)->{map_id,local}`。PlayerController 改跑全域 cell、移除離散 `edge_exit_attempted`、新增 `rebase(delta,new_grid)` 保留滑動補間。main 在 `entered_cell` 反查 →（跨圖時）recenter（重建 grid/renderer + `rebase`）→ 沿用既有內容觸發碼（pos 用 local）。怪物 Phase 1 不動邏輯。

**Tech Stack:** Godot 4.7 (GDScript)、GUT 9.7 測試框架。

## Global Constraints

- 給使用者的說明/建議一律繁體中文（程式碼/commit 訊息維持既有慣例）。
- 新 `class_name` 的 `.gd` 需先 `godot --headless --path . --import` 生 `.gd.uid` 並一併 commit。
- 每個 task commit 前確認分支仍為 `feat/seamless-runtime-world`（使用者可能同時在 `.claude/worktrees/` 改 world-bible 純 docs，與本案無關）。
- pre-release：breaking change 一律可接受，不寫相容/遷移層。
- Godot 路徑：`godot` 不在 PATH 就用 `/Applications/Godot.app/Contents/MacOS/Godot`。
- 單檔測試：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<file>.gd -gexit`
- 全套測試：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- 起點：分支 tip `43ec70c`（spec 已 commit），全套 756/756 綠。

---

## File Structure

- **Create** `engine/world/world_grid.gd` — `WorldGrid`：統一 grid 反查 + 合併 passability（純邏輯，注入 loader）。
- **Create** `tests/engine/world/test_world_grid.gd` — WorldGrid 單測。
- **Modify** `engine/map/world_stitch.gd` — 新增 static `window_for(map)->{half,center}`（half/center 單一來源）。
- **Modify** `tests/engine/map/test_world_stitch.gd` — `window_for` 測試。
- **Modify** `presentation/world/world_stitch_renderer.gd` — `rebuild` 改用 `WorldStitch.window_for`（行為不變）。
- **Modify** `presentation/world/player_controller.gd` — 吃 `WorldGrid`、全域移動、移除 `edge_exit_attempted`、新增 `rebase`、持有 `_move_tween`。
- **Modify** `tests/presentation/test_player_controller.gd` — 改用 WorldGrid、移除 edge-exit 測試、新增跨鄰圖 + rebase 測試。
- **Modify** `presentation/world/main.gd` — `_on_entered_cell` 反查 + recenter；移除 `_on_edge_exit_attempted`；`_is_passable`、`_ready`/`_enter_via_link`/`_on_loaded` 接 `WorldGrid`。

---

## Task 1: `WorldStitch.window_for` 單一來源 + renderer 改用

把渲染窗 `half`/`center` 公式抽成 `WorldStitch.window_for`，讓 `WorldGrid`（Task 2）與 `WorldStitchRenderer` 共用同一公式 → 玩法座標與視覺座標天生一致。本 task 不改任何行為。

**Files:**
- Modify: `engine/map/world_stitch.gd`
- Modify: `presentation/world/world_stitch_renderer.gd:16-21`
- Test: `tests/engine/map/test_world_stitch.gd`

**Interfaces:**
- Produces: `static WorldStitch.window_for(map: MapData) -> Dictionary`（回 `{ "half": int, "center": Vector2i }`，`half = max(width,height)`、`center = Vector2i(width/2, height/2)`）。

- [ ] **Step 1: 寫失敗測試**

加到 `tests/engine/map/test_world_stitch.gd` 末尾：

```gdscript
func test_window_for_half_and_center():
	var m := _map("a", 6, 4)
	var win := WorldStitch.window_for(m)
	assert_eq(win["half"], 6, "half = max(width, height)")
	assert_eq(win["center"], Vector2i(3, 2), "center = (width/2, height/2)")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_stitch.gd -gexit`
Expected: FAIL（`window_for` 不存在）

- [ ] **Step 3: 實作 `window_for`**

在 `engine/map/world_stitch.gd` 的 `place` 之前加：

```gdscript
# 渲染/玩法窗的 half/center 單一來源（WorldGrid 與 WorldStitchRenderer 共用，確保座標一致）。
static func window_for(map: MapData) -> Dictionary:
	return {
		"half": max(map.width, map.height),
		"center": Vector2i(map.width / 2, map.height / 2),
	}
```

- [ ] **Step 4: renderer 改用 `window_for`**

把 `presentation/world/world_stitch_renderer.gd` 的 `rebuild` 開頭：

```gdscript
	var half: int = max(current_map.width, current_map.height)
	var center := Vector2i(current_map.width / 2, current_map.height / 2)
	var placed := WorldStitch.place(current_map, loader, half, center)
```

改為：

```gdscript
	var win := WorldStitch.window_for(current_map)
	var placed := WorldStitch.place(current_map, loader, win["half"], win["center"])
```

- [ ] **Step 5: 跑測試確認通過（含既有 renderer 測試未退化）**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_stitch.gd -gexit`
Then: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_stitch_renderer.gd -gexit`
Expected: 兩者 PASS

- [ ] **Step 6: Commit**

```bash
git add engine/map/world_stitch.gd presentation/world/world_stitch_renderer.gd tests/engine/map/test_world_stitch.gd
git commit -m "refactor(world): WorldStitch.window_for — single source for stitch window"
```

---

## Task 2: `WorldGrid`（統一 grid 反查 + 合併 passability）

新增純邏輯 `WorldGrid`：把焦點圖 + 一圈鄰圖（含對角）投影成全域 cell，提供反查與 passability。本案所有 phase 的基礎層。

**Files:**
- Create: `engine/world/world_grid.gd`
- Test: `tests/engine/world/test_world_grid.gd`

**Interfaces:**
- Consumes: `WorldStitch.window_for`、`WorldStitch.place`（Task 1）；`MapBuilder.is_walkable_type`；`MapData.get_tile`。
- Produces:
  - `WorldGrid.new(focus_map: MapData, loader: Callable) -> WorldGrid`（`loader: Callable(String)->MapData`，未知回 null）
  - `is_walkable(global: Vector2i) -> bool`（未被任何 region 覆蓋＝false）
  - `resolve(global: Vector2i) -> Dictionary`（`{ "map_id": String, "local": Vector2i }` 或空 `{}`）
  - `regions() -> Array`（`[{ "map": MapData, "ox": int, "oy": int }]`）

- [ ] **Step 1: 寫失敗測試**

Create `tests/engine/world/test_world_grid.gd`：

```gdscript
extends GutTest

var _world := {}

func _floor_map(id: String, w: int, h: int, neighbors := {}) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.neighbors = neighbors
	var t := PackedInt32Array()
	t.resize(w * h)   # 全 0 = FLOOR
	m.tiles = t
	return m

func _with_wall(m: MapData, cell: Vector2i) -> MapData:
	var t := m.tiles
	t[cell.y * m.width + cell.x] = MapData.TileType.WALL
	m.tiles = t
	return m

func _loader(id: String) -> MapData:
	return _world.get(id, null)

func _null_loader(_id: String) -> MapData:
	return null

func test_single_map_resolve_and_walkable():
	var a := _floor_map("a", 3, 3)
	var wg := WorldGrid.new(a, Callable(self, "_null_loader"))
	assert_eq(wg.resolve(Vector2i(1, 1)), { "map_id": "a", "local": Vector2i(1, 1) })
	assert_true(wg.is_walkable(Vector2i(1, 1)), "焦點圖可走格")

func test_outside_region_is_wall_and_unresolved():
	var a := _floor_map("a", 3, 3)
	var wg := WorldGrid.new(a, Callable(self, "_null_loader"))
	assert_false(wg.is_walkable(Vector2i(1, -1)), "外緣無鄰 = 牆")
	assert_eq(wg.resolve(Vector2i(1, -1)), {}, "未覆蓋格 resolve 回空")

func test_wall_tile_not_walkable_but_resolvable():
	var a := _with_wall(_floor_map("a", 3, 3), Vector2i(1, 1))
	var wg := WorldGrid.new(a, Callable(self, "_null_loader"))
	assert_false(wg.is_walkable(Vector2i(1, 1)), "WALL tile 不可走")
	assert_eq(wg.resolve(Vector2i(1, 1)), { "map_id": "a", "local": Vector2i(1, 1) }, "WALL 仍可反查")

func test_east_neighbor_resolve_and_walkable():
	var a := _floor_map("a", 3, 3, { GridDirection.Dir.EAST: "e" })
	var e := _floor_map("e", 3, 3, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var wg := WorldGrid.new(a, Callable(self, "_loader"))
	# a 在原點、e 在 ox = a.width = 3
	assert_eq(wg.resolve(Vector2i(3, 1)), { "map_id": "e", "local": Vector2i(0, 1) })
	assert_true(wg.is_walkable(Vector2i(3, 1)), "鄰圖可走格")

func test_diagonal_neighbor_resolved():
	var nw := _floor_map("nw", 5, 5, { GridDirection.Dir.EAST: "ne", GridDirection.Dir.SOUTH: "sw" })
	var ne := _floor_map("ne", 5, 5, { GridDirection.Dir.WEST: "nw", GridDirection.Dir.SOUTH: "se" })
	var sw := _floor_map("sw", 5, 5, { GridDirection.Dir.NORTH: "nw", GridDirection.Dir.EAST: "se" })
	var se := _floor_map("se", 5, 5, { GridDirection.Dir.WEST: "sw", GridDirection.Dir.NORTH: "ne" })
	_world = { "nw": nw, "ne": ne, "sw": sw, "se": se }
	var wg := WorldGrid.new(nw, Callable(self, "_loader"))
	# se 對角在 (5,5)，其 local (0,0)
	assert_eq(wg.resolve(Vector2i(5, 5)), { "map_id": "se", "local": Vector2i(0, 0) })

func test_regions_match_world_stitch_place():
	var a := _floor_map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _floor_map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var wg := WorldGrid.new(a, Callable(self, "_loader"))
	var win := WorldStitch.window_for(a)
	var placed := WorldStitch.place(a, Callable(self, "_loader"), win["half"], win["center"])
	var wg_by_id := {}
	for r in wg.regions():
		wg_by_id[r["map"].map_id] = Vector2i(r["ox"], r["oy"])
	var ws_by_id := {}
	for r in placed:
		ws_by_id[r["map"].map_id] = Vector2i(r["ox"], r["oy"])
	assert_eq(wg_by_id, ws_by_id, "WorldGrid.regions 偏移與 WorldStitch.place 同源一致")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_grid.gd -gexit`
Expected: FAIL（`WorldGrid` 不存在）

- [ ] **Step 3: 實作 `WorldGrid`**

Create `engine/world/world_grid.gd`：

```gdscript
class_name WorldGrid
extends RefCounted

# 統一可遊玩 grid：焦點圖 + 一圈鄰圖（含對角）投影到全域 cell。
# 純邏輯，loader 注入（peek_map）。沿用 WorldStitch.window_for/place → 與 WorldStitchRenderer 座標一致。
# 重疊（well-formed 世界不會發生；WorldStitch 的 visited 已去重）採「第一寫入者勝」確定性處理。

var _owner: Dictionary = {}     # Vector2i(global) -> { "map_id": String, "local": Vector2i }
var _walkable: Dictionary = {}  # Vector2i(global) -> true
var _regions: Array = []        # [{ "map": MapData, "ox": int, "oy": int }]

func _init(focus_map: MapData, loader: Callable) -> void:
	if focus_map == null:
		return
	var win := WorldStitch.window_for(focus_map)
	_regions = WorldStitch.place(focus_map, loader, win["half"], win["center"])
	for region in _regions:
		var m: MapData = region["map"]
		var ox: int = region["ox"]
		var oy: int = region["oy"]
		for y in m.height:
			for x in m.width:
				var g := Vector2i(x + ox, y + oy)
				if _owner.has(g):
					continue   # 第一寫入者勝（BFS 順序，確定性）
				var local := Vector2i(x, y)
				_owner[g] = { "map_id": m.map_id, "local": local }
				if MapBuilder.is_walkable_type(m.get_tile(local)):
					_walkable[g] = true

func is_walkable(global: Vector2i) -> bool:
	return _walkable.has(global)

func resolve(global: Vector2i) -> Dictionary:
	return _owner.get(global, {})

func regions() -> Array:
	return _regions
```

- [ ] **Step 4: 生 `.gd.uid`**

Run: `godot --headless --path . --import`
（匯入後 `engine/world/world_grid.gd.uid` 會生成。）

- [ ] **Step 5: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_grid.gd -gexit`
Expected: PASS（6 測試）

- [ ] **Step 6: Commit（含 .gd.uid）**

```bash
git add engine/world/world_grid.gd engine/world/world_grid.gd.uid tests/engine/world/test_world_grid.gd
git commit -m "feat(world): WorldGrid — unified global grid with reverse-lookup + merged passability"
```

---

## Task 3: PlayerController 跑全域 grid + `rebase` + 移除離散邊界

PlayerController 改吃 `WorldGrid`、`_pos` 語意改全域 cell、移除 `edge_exit_attempted`、新增 `rebase` 保留滑動補間。

**Files:**
- Modify: `presentation/world/player_controller.gd`
- Test: `tests/presentation/test_player_controller.gd`

**Interfaces:**
- Consumes: `WorldGrid`（Task 2）。
- Produces:
  - `setup(world_grid: WorldGrid, start_pos: Vector2i, start_facing: int)`（簽章改：第一參數由 `GridData` 換 `WorldGrid`）
  - `rebase(delta: Vector2i, new_grid: WorldGrid) -> void`
  - 移除訊號 `edge_exit_attempted`。

- [ ] **Step 1: 改寫測試（先讓它對應新行為而失敗）**

把 `tests/presentation/test_player_controller.gd` 中以下三個既有測試**整段刪除**：`test_move_emits_entered_cell_with_new_pos`、`test_blocked_move_does_not_emit_entered_cell`、`test_edge_move_emits_edge_exit_attempted`、`test_inbounds_wall_does_not_emit_edge_exit`、`test_setup_emits_facing_changed`、`test_disabled_ignores_input`、`test_enabled_processes_input`，以及 `_make_pc` helper。

於檔案頂端（`extends GutTest` 之下）加 helper，並加入新測試：

```gdscript
var _world := {}

func _floor_map(id: String, w: int, h: int, neighbors := {}) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.neighbors = neighbors
	var t := PackedInt32Array()
	t.resize(w * h)
	m.tiles = t
	return m

func _with_wall(m: MapData, cell: Vector2i) -> MapData:
	var t := m.tiles
	t[cell.y * m.width + cell.x] = MapData.TileType.WALL
	m.tiles = t
	return m

func _loader(id: String) -> MapData:
	return _world.get(id, null)

func _null_loader(_id: String) -> MapData:
	return null

func _wg(map: MapData, loader := Callable()) -> WorldGrid:
	if not loader.is_valid():
		loader = Callable(self, "_null_loader")
	return WorldGrid.new(map, loader)

func _make_pc(world_grid: WorldGrid, pos: Vector2i, facing: int) -> PlayerController:
	var pc := PlayerController.new()
	add_child_autofree(pc)
	pc.setup(world_grid, pos, facing)
	return pc

func test_setup_emits_facing_changed():
	var pc := PlayerController.new()
	add_child_autofree(pc)
	watch_signals(pc)
	pc.setup(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.EAST)
	assert_signal_emitted_with_parameters(pc, "facing_changed", [GridDirection.Dir.EAST])

func test_move_emits_entered_cell_with_new_pos():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)   # 北 → (1,0)
	assert_signal_emitted_with_parameters(pc, "entered_cell", [Vector2i(1, 0)])

func test_blocked_by_wall_does_not_emit_entered_cell():
	var pc := _make_pc(_wg(_with_wall(_floor_map("a", 3, 3), Vector2i(1, 0))), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)   # 北邊牆，不動
	assert_signal_not_emitted(pc, "entered_cell")
	assert_eq(pc._pos, Vector2i(1, 1))

func test_outer_rim_blocks_move_no_signal():
	# 站最北排 (1,0) 向北 → 出界（無鄰）→ 統一 grid 視為牆，不動、不發訊號（無 edge_exit_attempted）。
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 0), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)
	assert_signal_not_emitted(pc, "entered_cell")
	assert_eq(pc._pos, Vector2i(1, 0), "外緣牆擋住不動")

func test_no_edge_exit_attempted_signal_exists():
	var pc := PlayerController.new()
	add_child_autofree(pc)
	assert_false(pc.has_signal("edge_exit_attempted"), "離散邊界訊號已移除")

func test_walk_across_into_east_neighbor():
	# 焦點圖 a(3x3) 東鄰 e(3x3)；玩家站 a 東緣 (2,1) 面向 EAST 前進 → 全域 (3,1) = e 的 local(0,1) 可走。
	var a := _floor_map("a", 3, 3, { GridDirection.Dir.EAST: "e" })
	var e := _floor_map("e", 3, 3, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var pc := _make_pc(_wg(a, Callable(self, "_loader")), Vector2i(2, 1), GridDirection.Dir.EAST)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)
	assert_signal_emitted_with_parameters(pc, "entered_cell", [Vector2i(3, 1)])
	assert_eq(pc._pos, Vector2i(3, 1), "連續走進鄰圖（全域 cell）")

func test_disabled_ignores_input():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	pc.set_enabled(false)
	var ev := InputEventAction.new()
	ev.action = "move_forward"
	ev.pressed = true
	pc._unhandled_input(ev)
	assert_eq(pc._pos, Vector2i(1, 1))

func test_enabled_processes_input():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	var ev := InputEventAction.new()
	ev.action = "move_forward"
	ev.pressed = true
	pc._unhandled_input(ev)
	assert_eq(pc._pos, Vector2i(1, 0))

func test_rebase_shifts_pos_and_swaps_grid():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(2, 2), GridDirection.Dir.NORTH)
	var g2 := _wg(_floor_map("b", 3, 3))
	pc.rebase(Vector2i(-3, 0), g2)
	assert_eq(pc._pos, Vector2i(-1, 2), "rebase 後 _pos 平移 delta")
	assert_eq(pc._world_grid, g2, "rebase 後切換到新 grid")
```

> 保留既有的 `test_nearest_equivalent_angle_*`、`test_input_actions_registered`、`test_turn_emits_facing_changed`（不動）。

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_player_controller.gd -gexit`
Expected: FAIL（`setup` 仍吃 GridData / 無 `rebase` / 仍有 `edge_exit_attempted`）

- [ ] **Step 3: 改寫 PlayerController**

把 `presentation/world/player_controller.gd` 整檔改為：

```gdscript
class_name PlayerController
extends Node3D

signal entered_cell(pos: Vector2i)
signal facing_changed(facing: int)

const MOVE_TIME := 0.18

var _world_grid: WorldGrid
var _pos: Vector2i           # 全域 cell
var _facing: int
var _is_busy := false
var _enabled := true
var _move_tween: Tween

func set_enabled(enabled: bool) -> void:
	_enabled = enabled

func setup(world_grid: WorldGrid, start_pos: Vector2i, start_facing: int) -> void:
	_world_grid = world_grid
	_pos = start_pos
	_facing = start_facing
	_apply_transform_immediate()
	facing_changed.emit(_facing)

# recenter：把 _pos/position 平移 delta、切換到新框架的 grid，並把進行中的滑動補間
# 殺掉、在新框架重建到 cell_to_world(_pos)（保留滑動視覺）。全體同步平移 → 視覺零跳動。
func rebase(delta: Vector2i, new_grid: WorldGrid) -> void:
	_world_grid = new_grid
	_pos += delta
	position += GridGeometry.cell_to_world(delta)
	if _move_tween != null and _move_tween.is_valid() and _move_tween.is_running():
		_move_tween.kill()
		_is_busy = true
		_move_tween = create_tween()
		_move_tween.tween_property(self, "position", GridGeometry.cell_to_world(_pos), MOVE_TIME)
		_move_tween.finished.connect(func(): _is_busy = false)

func _apply_transform_immediate() -> void:
	position = GridGeometry.cell_to_world(_pos)
	rotation.y = GridGeometry.facing_to_yaw(_facing)

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or _is_busy or _world_grid == null:
		return
	if event.is_action_pressed("move_forward"):
		_attempt_move(GridMovement.Move.FORWARD)
	elif event.is_action_pressed("move_back"):
		_attempt_move(GridMovement.Move.BACKWARD)
	elif event.is_action_pressed("strafe_left"):
		_attempt_move(GridMovement.Move.STRAFE_LEFT)
	elif event.is_action_pressed("strafe_right"):
		_attempt_move(GridMovement.Move.STRAFE_RIGHT)
	elif event.is_action_pressed("turn_left"):
		_attempt_turn(GridDirection.turn_left(_facing))
	elif event.is_action_pressed("turn_right"):
		_attempt_turn(GridDirection.turn_right(_facing))

func _attempt_move(move: int) -> void:
	var move_dir := GridMovement.direction_of(_facing, move)
	var target := _pos + GridDirection.to_vector(move_dir)
	if not _world_grid.is_walkable(target):
		return   # 牆（含外緣無鄰）→ 不動；無離散切圖
	_pos = target
	entered_cell.emit(_pos)
	_is_busy = true
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", GridGeometry.cell_to_world(_pos), MOVE_TIME)
	_move_tween.finished.connect(func(): _is_busy = false)

func _attempt_turn(new_facing: int) -> void:
	_facing = new_facing
	facing_changed.emit(_facing)
	_is_busy = true
	var tween := create_tween()
	var target_yaw := GridGeometry.facing_to_yaw(_facing)
	target_yaw = _nearest_equivalent_angle(rotation.y, target_yaw)
	tween.tween_property(self, "rotation:y", target_yaw, MOVE_TIME)
	tween.finished.connect(func(): _is_busy = false)

func _nearest_equivalent_angle(current: float, target: float) -> float:
	var diff := fposmod(target - current + PI, TAU) - PI
	return current + diff
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_player_controller.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add presentation/world/player_controller.gd tests/presentation/test_player_controller.gd
git commit -m "feat(world): PlayerController on unified WorldGrid + rebase; drop discrete edge-exit"
```

---

## Task 4: main 接統一 grid — `entered_cell` 反查 + recenter，移除離散邊界

main 改用 `WorldGrid`：`_on_entered_cell` 反查 →（跨圖時）recenter → 沿用既有內容觸發；移除 `_on_edge_exit_attempted`；`_is_passable`、`_ready`/`_enter_via_link`/`_on_loaded` 接 `WorldGrid`。

> main 為場景 wiring（無既有單測，與專案慣例一致）；本 task 以「全套測試綠 + `./run.sh --headless` boot 乾淨」驗證，外加人工視覺 gate。反查/passability/rebase 的邏輯已由 Task 2/3 單測覆蓋。

**Files:**
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes: `WorldGrid`（Task 2）、`PlayerController.setup/rebase`（Task 3）、`MapManager.peek_map`。

- [ ] **Step 1: 加 `_world_grid` 欄位 + helper**

在 `presentation/world/main.gd` 的 `var _world_renderer: WorldStitchRenderer` 之下加：

```gdscript
var _world_grid: WorldGrid
```

在 `_rebuild_monsters_for_current_map()` 之前加 helper：

```gdscript
func _build_world_grid() -> void:
	_world_grid = WorldGrid.new(MapManager.current_map, Callable(MapManager, "peek_map"))
```

- [ ] **Step 2: `_ready` 接 WorldGrid**

`_ready` 中把：

```gdscript
	_world_renderer.rebuild(MapManager.current_map)
```

改為（在其後補建 grid）：

```gdscript
	_world_renderer.rebuild(MapManager.current_map)
	_build_world_grid()
```

並把 `_ready` 末段：

```gdscript
	_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)
```

改為：

```gdscript
	_player.setup(_world_grid, map.start_pos, map.start_facing)
```

移除 `_ready` 中這行連線（連同 Step 5 一起整段移除 handler）：

```gdscript
	_player.edge_exit_attempted.connect(_on_edge_exit_attempted)
```

- [ ] **Step 3: 重寫 `_on_entered_cell` + 加 `_recenter_to`**

把整個 `_on_entered_cell` 函式換為：

```gdscript
func _on_entered_cell(global: Vector2i) -> void:
	var r := _world_grid.resolve(global)
	if r.is_empty():
		return   # 理論上 walkable 格必可反查；防呆
	var map_id: String = r["map_id"]
	var local: Vector2i = r["local"]
	if map_id != GameState.current_map_id:
		_recenter_to(map_id, local, global)
	# recenter 後 MapManager.current_map ＝玩家所在圖、local ＝該圖 cell：沿用既有內容觸發（pos → local）。
	GameState.player_pos = local
	GameState.mark_explored(GameState.current_map_id, local, MapManager.current_map.width, MapManager.current_map.height)
	GameState.notify_enter(GameState.current_map_id, local)
	GameState.refresh_collect()
	var link := MapTransitions.resolve_link(MapManager.current_map, local)
	if not link.is_empty():
		_enter_via_link(link["map"], link["entry"])
		return
	var res := _overworld_monsters.step(local, Callable(self, "_is_passable"))
	_monster_layer.apply_moves(_overworld_monsters.live())
	GameState.monster_state[GameState.current_map_id] = _overworld_monsters.to_save()
	if res["contact"] != "":
		_start_combat_for_uid(res["contact"])
		return
	if _has_unopened_chest(local):
		_prompt_chest(local)
		return
	if _try_scene(local):
		return
	if _try_quest_giver(local):
		return
	if _try_vendor(local):
		return
	var text := TileMessages.for_tile(MapManager.current_map.get_tile(local))
	if text != "":
		GameState.message_log.push(text)

# 跨圖 recenter：重建焦點圖/grid/renderer/怪物，玩家以 rebase 平移到新框架（保留滑動 → 零跳動）。
func _recenter_to(map_id: String, local: Vector2i, global: Vector2i) -> void:
	var delta := local - global   # = -新焦點圖在舊框架的偏移
	MapManager.enter_map(map_id, GameState.cleared_for(map_id))
	_build_world_grid()
	_world_renderer.rebuild(MapManager.current_map)
	_player.rebase(delta, _world_grid)
	_rebuild_monsters_for_current_map()
	GameState.current_map_id = map_id
```

- [ ] **Step 4: `_is_passable` 改用 WorldGrid**

把：

```gdscript
func _is_passable(cell: Vector2i) -> bool:
	return MapManager.current_grid.is_walkable(cell)   # is_walkable 已含 in_bounds
```

改為：

```gdscript
func _is_passable(cell: Vector2i) -> bool:
	return _world_grid.is_walkable(cell)   # 統一 grid（外緣無鄰 = 牆）
```

- [ ] **Step 5: 移除離散邊界 handler**

整段刪除 `_on_edge_exit_attempted`（從 `# 邊緣接壤：即時、無黑幕…` 註解到函式結尾），以及 Step 2 已移除的 `edge_exit_attempted.connect` 連線。

- [ ] **Step 6: `_enter_via_link` 與 `_on_loaded` 接 WorldGrid**

在 `_enter_via_link` 中把：

```gdscript
	_world_renderer.rebuild(MapManager.current_map)
	_rebuild_monsters_for_current_map()
	_player.setup(MapManager.current_grid, pos, facing)
```

改為：

```gdscript
	_world_renderer.rebuild(MapManager.current_map)
	_build_world_grid()
	_rebuild_monsters_for_current_map()
	_player.setup(_world_grid, pos, facing)
```

在 `_on_loaded` 中把：

```gdscript
	_rebuild_monsters_for_current_map()
	_player.setup(MapManager.current_grid, GameState.player_pos, GameState.player_facing)
```

改為：

```gdscript
	_build_world_grid()
	_rebuild_monsters_for_current_map()
	_player.setup(_world_grid, GameState.player_pos, GameState.player_facing)
```

- [ ] **Step 7: 全套測試 + headless boot 驗證**

Run（全套）: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全綠（≥ 756 + 新增 WorldGrid/PlayerController 測試；無 PlayerController 移除的測試殘留）

Run（boot smoke）: `./run.sh --headless`
Expected: 乾淨啟動數秒、無 GDScript 錯誤/紅字（手動 Ctrl-C 結束）。確認 console 無 `_on_edge_exit_attempted`/`current_grid` 相關 nil 錯誤。

- [ ] **Step 8: Commit**

```bash
git add presentation/world/main.gd
git commit -m "feat(world): seamless crossing in main — entered_cell reverse-lookup + recenter, drop edge-exit"
```

---

## 人工視覺 gate（無法自動測，交付後請使用者 `./run.sh`）

往東北走，確認：跨 wild 邊界為**連續移動、無黑幕、無位置跳動**；地形/裝飾無縫拼接；踏入鄰圖後內容（如該圖寶箱/遭遇）正確觸發。怪物跨界追擊仍為 Phase 2，本階段鄰圖怪維持靜態。

---

## Self-Review（plan↔spec 對照）

- **Spec coverage：** `WorldGrid`(Task 2) ✓；`window_for` 單一來源(Task 1) ✓；PlayerController 全域移動 + 移除 edge_exit + rebase(Task 3) ✓；main recenter-first + 反查 + 內容沿用 + portal 維持離散(Task 4，`_enter_via_link` 不動) ✓；`_is_passable`→WorldGrid(Task 4) ✓；怪物 Phase 1 不動邏輯（`_rebuild_monsters_for_current_map` 沿用）✓；存檔不升版（player_pos 存 local、monster_state per-map）✓；`.gd.uid`(Task 2 Step 4) ✓。
- **重疊退化：** spec 列為確定性保證；因 `WorldStitch` 的 `visited` 已去重，實務上不會由 `place` 產生重疊，故 `_owner` 的「第一寫入者勝」為防呆，行為由 `test_diagonal_neighbor_resolved`（單一置入）間接保障，未另寫人造重疊測試。
- **型別一致：** `setup(WorldGrid,...)`、`rebase(Vector2i, WorldGrid)`、`resolve(...)->{map_id,local}`、`is_walkable(Vector2i)->bool`、`regions()->Array`、`window_for(MapData)->{half,center}` 全 plan 內一致。
- **Placeholder scan：** 無 TBD/TODO；每個改碼步驟均附完整程式碼。
