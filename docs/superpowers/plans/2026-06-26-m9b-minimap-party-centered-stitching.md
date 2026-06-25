# M9b 迷你地圖 v2（以隊伍為中心 + 鄰圖拼裝 + 放大）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把小地圖改成以隊伍為中心的捲動視窗，觸及地圖邊界時把相鄰地圖（含對角）依 `neighbors` 拼進來，每張圖各套自己的 explored 迷霧，整體放大約 3×。

**Architecture:** 新增無副作用 `MapManager.peek_map(id)` 偷看鄰圖；新增純 `WorldStitch.place()` 以 BFS 把當前圖+相交鄰圖置入全域偏移（沿用 `MapTransitions` 對邊對齊）；改寫 `MiniMap` 為固定視窗面板，`_draw` 用 `WorldStitch` 取得拼裝結果、逐圖逐格依各自 explored 畫色塊、隊伍恆置中。`main.gd` 不需改（M9 已在 4 個切圖/讀檔點呼叫 `_mini_map.refresh()`）。

**Tech Stack:** Godot 4.7 + GDScript；GUT 9.7 測試；純 2D `_draw()` UI。

## Global Constraints

- 引擎二進位不在 PATH：所有 godot 指令用 `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"`。
- 全套測試：`"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`（現況 315 綠）。聚焦單檔：加 `-gselect=<script_name.gd>`。
- 三層架構：`engine/` 純邏輯、`autoload/` 全域單例、`presentation/` Godot 節點。UI 沿用「程式建構 placeholder」慣例（`_draw` 不寫像素測試；純輔助函式才測）。
- 座標：`MapData`（`width/height/map_id/get_tile(Vector2i)->int/has_link(Vector2i)->bool/has_neighbor(int)->bool/get_neighbor(int)->String`，`neighbors: Dictionary[int(GridDirection.Dir)->String]`）；`MapData.TileType{FLOOR=0,WALL=1,DOOR=2,STAIRS_UP=3,STAIRS_DOWN=4}`；`GridDirection.Dir{NORTH=0,EAST=1,SOUTH=2,WEST=3}`。
- 拼裝對邊對齊（沿用 `MapTransitions`）：EAST 子圖 ox=offset.x+cur.width；WEST ox=offset.x-nb.width；SOUTH oy=offset.y+cur.height；NORTH oy=offset.y-nb.height。
- 視窗常數（可微調）：`RADIUS=6`（視窗 13×13）、`CELL_PX=22`、`PAD=6`。
- 存檔不變（v4）；拼裝只讀 explored，不新增欄位。
- commit 訊息結尾：`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`。

---

## File Structure

- **Modify** `autoload/map_manager.gd` — 加 `peek_map(id)` 無副作用載入。
- **Create** `engine/map/world_stitch.gd` — 純 BFS 拼裝（`class_name WorldStitch`）。
- **Modify** `presentation/ui/mini_map.gd` — 改寫成以隊伍為中心 + 拼裝視窗（新常數/快取/loader/純輔助/`_draw`）。
- **Modify** `tests/autoload/test_map_manager.gd` — 加 `peek_map` 測試。
- **Create** `tests/engine/map/test_world_stitch.gd` — 拼裝 BFS/偏移/對角/裁剪測試。
- **Modify** `tests/presentation/test_mini_map.gd` — 加 `panel_side`/`cell_top_left` 純輔助測試（`tile_color` 既有測試保留）。

---

### Task 1: MapManager.peek_map（無副作用載入鄰圖）

**Files:**
- Modify: `autoload/map_manager.gd`
- Test: `tests/autoload/test_map_manager.gd`

**Interfaces:**
- Consumes: 既有 `MAPS_DIR`、`MapImporter.parse(text)->MapData`。
- Produces: `func peek_map(id: String) -> MapData` — 載入 `MAPS_DIR/id.json` 並設 `map.map_id=id`，**不**動 `current_map/current_grid`；檔不存在/讀空/解析失敗 → `null`（不 assert）。

- [ ] **Step 1: 寫失敗測試**

In `tests/autoload/test_map_manager.gd`, append:

```gdscript
func test_peek_map_loads_without_changing_current():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	mm.load_by_id("wild_nw")            # 先設一個 current
	var before = mm.current_map
	var peeked = mm.peek_map("town_oak")
	assert_not_null(peeked)
	assert_eq(peeked.map_id, "town_oak")
	assert_eq(mm.current_map, before, "peek_map 不應改動 current_map")

func test_peek_map_unknown_returns_null():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	assert_null(mm.peek_map("does_not_exist"))
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_manager.gd -gexit`
Expected: FAIL（`peek_map` 不存在）。

- [ ] **Step 3: 實作**

In `autoload/map_manager.gd`, after `load_by_id` (around line 24) add:

```gdscript
# 無副作用載入（拼裝鄰圖用）：不動 current_map/current_grid；失敗回 null（不 assert）。
func peek_map(id: String) -> MapData:
	var path := "%s/%s.json" % [MAPS_DIR, id]
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return null
	var map := MapImporter.parse(text)
	if map == null:
		return null
	map.map_id = id
	return map
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_manager.gd -gexit`
Expected: PASS（既有 4 + 新 2）。

- [ ] **Step 5: Commit**

```bash
git add autoload/map_manager.gd tests/autoload/test_map_manager.gd
git commit -m "feat(map): MapManager.peek_map 無副作用載入（拼裝鄰圖用）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: WorldStitch.place（純 BFS 拼裝）

**Files:**
- Create: `engine/map/world_stitch.gd`
- Test: `tests/engine/map/test_world_stitch.gd` (create)

**Interfaces:**
- Consumes: `MapData`（width/height/map_id/has_neighbor/get_neighbor）；`GridDirection.Dir`；注入的 `loader: Callable(String)->MapData`。
- Produces: `static func place(origin_map: MapData, loader: Callable, half: int, center: Vector2i) -> Array` — 回傳 `[{ "map": MapData, "ox": int, "oy": int }, …]`，BFS 走 `neighbors` 置入全域偏移，只含與視窗（`center±half`，含端點）相交的圖；`map_id` 去重（首次置入勝）；origin 一定置入。

- [ ] **Step 1: 寫失敗測試**

Create `tests/engine/map/test_world_stitch.gd`:

```gdscript
extends GutTest

var _world := {}

func _map(id: String, w: int, h: int, neighbors: Dictionary = {}) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.neighbors = neighbors
	return m

func _loader(id: String) -> MapData:
	return _world.get(id, null)

func _by_id(placed: Array) -> Dictionary:
	var d := {}
	for p in placed:
		d[p["map"].map_id] = p
	return d

func test_single_map_no_neighbors():
	var m := _map("a", 5, 5)
	var placed := WorldStitch.place(m, Callable(self, "_loader"), 6, Vector2i(2, 2))
	assert_eq(placed.size(), 1)
	assert_eq(placed[0]["map"], m)
	assert_eq(placed[0]["ox"], 0)
	assert_eq(placed[0]["oy"], 0)

func test_east_neighbor_offset():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var placed := WorldStitch.place(a, Callable(self, "_loader"), 6, Vector2i(2, 2))
	var by_id := _by_id(placed)
	assert_true(by_id.has("e"))
	assert_eq(by_id["e"]["ox"], 5)   # origin.width
	assert_eq(by_id["e"]["oy"], 0)

func test_west_and_north_offsets_use_neighbor_dims():
	var a := _map("a", 5, 5, { GridDirection.Dir.WEST: "w", GridDirection.Dir.NORTH: "n" })
	var w := _map("w", 4, 5)
	var n := _map("n", 5, 3)
	_world = { "a": a, "w": w, "n": n }
	var placed := WorldStitch.place(a, Callable(self, "_loader"), 6, Vector2i(2, 2))
	var by_id := _by_id(placed)
	assert_eq(by_id["w"]["ox"], -4)  # -nb.width
	assert_eq(by_id["w"]["oy"], 0)
	assert_eq(by_id["n"]["ox"], 0)
	assert_eq(by_id["n"]["oy"], -3)  # -nb.height

func test_diagonal_neighbor_placed_once():
	var nw := _map("nw", 5, 5, { GridDirection.Dir.EAST: "ne", GridDirection.Dir.SOUTH: "sw" })
	var ne := _map("ne", 5, 5, { GridDirection.Dir.WEST: "nw", GridDirection.Dir.SOUTH: "se" })
	var sw := _map("sw", 5, 5, { GridDirection.Dir.NORTH: "nw", GridDirection.Dir.EAST: "se" })
	var se := _map("se", 5, 5, { GridDirection.Dir.WEST: "sw", GridDirection.Dir.NORTH: "ne" })
	_world = { "nw": nw, "ne": ne, "sw": sw, "se": se }
	var placed := WorldStitch.place(nw, Callable(self, "_loader"), 8, Vector2i(2, 2))
	var by_id := _by_id(placed)
	assert_true(by_id.has("se"), "對角圖應被拼進來")
	assert_eq(by_id["se"]["ox"], 5)
	assert_eq(by_id["se"]["oy"], 5)
	var se_count := 0
	for p in placed:
		if p["map"].map_id == "se":
			se_count += 1
	assert_eq(se_count, 1, "對角圖只置入一次（visited 去重）")

func test_small_window_excludes_neighbors():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5)
	_world = { "a": a, "e": e }
	# 隊伍 (0,0)、半徑 1 → 視窗 x[-1..1]；east 圖在 x[5..9] 不相交
	var placed := WorldStitch.place(a, Callable(self, "_loader"), 1, Vector2i(0, 0))
	assert_eq(placed.size(), 1)
	assert_false(_by_id(placed).has("e"))

func test_missing_neighbor_skipped():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	_world = { "a": a }   # "e" 不在 → loader 回 null
	var placed := WorldStitch.place(a, Callable(self, "_loader"), 6, Vector2i(2, 2))
	assert_eq(placed.size(), 1, "鄰圖載入失敗 → 略過、不崩")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_world_stitch.gd -gexit`
Expected: FAIL（`world_stitch.gd` 不存在 / `WorldStitch` 未定義）。

- [ ] **Step 3: 實作**

Create `engine/map/world_stitch.gd`:

```gdscript
class_name WorldStitch
extends Object

# 以隊伍為中心的視窗內，從當前圖出發 BFS 走 neighbors，把相交的地圖（含對角）
# 置入全域偏移。回傳 [{ "map": MapData, "ox": int, "oy": int }, …]。
# loader: Callable(String)->MapData（注入；未知/不存在回 null）。
# 對邊對齊沿用 MapTransitions：EAST 子圖貼當前圖右、WEST 貼左（用鄰圖寬）、
# SOUTH 貼下、NORTH 貼上（用鄰圖高）。視窗矩形 [center±half]（含端點）相交才置入。
static func place(origin_map: MapData, loader: Callable, half: int, center: Vector2i) -> Array:
	var placed: Array = []
	if origin_map == null:
		return placed
	var min_x := center.x - half
	var max_x := center.x + half
	var min_y := center.y - half
	var max_y := center.y + half
	var visited := { origin_map.map_id: true }
	placed.append({ "map": origin_map, "ox": 0, "oy": 0 })
	var i := 0
	while i < placed.size():
		var node: Dictionary = placed[i]
		i += 1
		var m: MapData = node["map"]
		var ox: int = node["ox"]
		var oy: int = node["oy"]
		for dir in [GridDirection.Dir.NORTH, GridDirection.Dir.EAST, GridDirection.Dir.SOUTH, GridDirection.Dir.WEST]:
			if not m.has_neighbor(dir):
				continue
			var nid: String = m.get_neighbor(dir)
			if visited.has(nid):
				continue
			var nb: MapData = loader.call(nid)
			if nb == null:
				continue
			var nox := ox
			var noy := oy
			match dir:
				GridDirection.Dir.EAST: nox = ox + m.width
				GridDirection.Dir.WEST: nox = ox - nb.width
				GridDirection.Dir.SOUTH: noy = oy + m.height
				GridDirection.Dir.NORTH: noy = oy - nb.height
			# 子圖全域矩形 [nox..nox+nb.width-1] × [noy..noy+nb.height-1] 與視窗相交？
			if nox > max_x or nox + nb.width - 1 < min_x or noy > max_y or noy + nb.height - 1 < min_y:
				continue
			visited[nid] = true
			placed.append({ "map": nb, "ox": nox, "oy": noy })
	return placed
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_world_stitch.gd -gexit`
Expected: PASS（7 測）。若報 `WorldStitch` 未定義/未宣告（新 `class_name` 尚未進 `.godot` global class cache），先跑一次編輯器 import 再重試：`"$GODOT" --headless --editor --quit`（`.godot/` gitignored、不改原始碼）。

- [ ] **Step 5: Commit**

```bash
git add engine/map/world_stitch.gd tests/engine/map/test_world_stitch.gd
git commit -m "feat(map): WorldStitch 純 BFS 鄰圖拼裝（全域偏移 + 視窗裁剪 + 對角去重）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: MiniMap 改寫（以隊伍為中心 + 拼裝視窗 + 放大）

**Files:**
- Modify: `presentation/ui/mini_map.gd`（整檔改寫）
- Test: `tests/presentation/test_mini_map.gd`

**Interfaces:**
- Consumes: `WorldStitch.place`（Task 2）、`MapManager.peek_map`（Task 1）、`MapManager.current_map`、`GameState.explored_for/player_pos/player_facing`。
- Produces:
  - 新常數 `RADIUS=6`、`CELL_PX=22`（取代舊 16）。
  - `static func panel_side() -> float`（面板邊長含 pad）。
  - `static func cell_top_left(global: Vector2i, center: Vector2i) -> Vector2`（全域格→面板像素左上角；隊伍 center 恆置中）。
  - `func _peek_cached(id) -> MapData` + `var _map_cache`（快取含 null）；`_MiniMapPanel.loader` 由 `setup` 綁定。
  - `tile_color`/`_facing_vec`/顏色常數不變。

- [ ] **Step 1: 寫失敗測試**

In `tests/presentation/test_mini_map.gd`, append (保留既有 `tile_color` 測試):

```gdscript
func test_panel_side_holds_full_window():
	var window_px := (2 * MiniMapScript.RADIUS + 1) * MiniMapScript.CELL_PX
	assert_eq(MiniMapScript.panel_side(), window_px + MiniMapScript.PAD * 2)

func test_cell_top_left_center_offset_is_radius_cells():
	var c := Vector2i(5, 5)
	var edge := MiniMapScript.PAD + MiniMapScript.RADIUS * MiniMapScript.CELL_PX
	assert_eq(MiniMapScript.cell_top_left(c, c), Vector2(edge, edge))

func test_cell_top_left_steps_by_cell_px():
	var c := Vector2i(2, 2)
	var a := MiniMapScript.cell_top_left(c, c)
	var b := MiniMapScript.cell_top_left(c + Vector2i(1, 1), c)
	assert_eq(b - a, Vector2(MiniMapScript.CELL_PX, MiniMapScript.CELL_PX))

func test_cell_top_left_depends_only_on_offset_from_center():
	# 相同「全域 - 中心」位移 → 相同像素（與絕對座標無關，含負座標鄰圖）
	assert_eq(MiniMapScript.cell_top_left(Vector2i(7, 3), Vector2i(5, 5)),
		MiniMapScript.cell_top_left(Vector2i(2, 8), Vector2i(0, 10)))
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_mini_map.gd -gexit`
Expected: FAIL（`RADIUS`/`panel_side`/`cell_top_left` 不存在）。

- [ ] **Step 3: 實作（整檔取代 `presentation/ui/mini_map.gd`）**

```gdscript
class_name MiniMap
extends CanvasLayer
# 右上角常駐俯視小地圖（以隊伍為中心 + 鄰圖拼裝 + 迷霧探索）。程式建構 UI，鏡射 Hud。
# 視窗 (2*RADIUS+1)² 格、隊伍恆置中、地圖捲動；觸及邊界拼進相鄰地圖（含對角）。
# 每張圖各套自己的 explored 迷霧。資料：MapManager.current_map/peek_map、GameState。

const RADIUS := 6        # 以隊伍為中心、每側可見格數（視窗 13×13）
const CELL_PX := 22
const PAD := 6
const BORDER := 1.0
const MARGIN := 12       # 離畫面右上角

const COL_BACKDROP := Color(0, 0, 0, 0.55)
const COL_BORDER := Color(1, 1, 1, 0.35)
const COL_FLOOR := Color(0.72, 0.72, 0.72)
const COL_WALL := Color(0.16, 0.16, 0.18)
const COL_DOOR := Color(0.78, 0.6, 0.28)
const COL_STAIRS_UP := Color(0.5, 0.72, 0.95)
const COL_STAIRS_DOWN := Color(0.66, 0.46, 0.85)
const COL_PORTAL := Color(0.36, 0.82, 0.46)
const COL_PLAYER := Color(0.95, 0.3, 0.3)

var _panel                       # _MiniMapPanel（untyped 以容許動態 .loader 屬性）
var _map_cache: Dictionary = {}  # id -> MapData（會快取 null，避免重試不存在的檔）

func setup(player: PlayerController) -> void:
	_panel = _MiniMapPanel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.loader = Callable(self, "_peek_cached")
	add_child(_panel)
	player.entered_cell.connect(func(_p): _panel.queue_redraw())
	player.facing_changed.connect(func(_f): _panel.queue_redraw())
	refresh()

# 切圖/讀檔後由 main 呼叫：清鄰圖快取（鄰里換了）+ 重設固定面板大小（右上角）+ 重畫。
func refresh() -> void:
	if _panel == null:
		return
	_map_cache.clear()
	var side := panel_side()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_top = MARGIN
	_panel.offset_bottom = MARGIN + side
	_panel.offset_right = -MARGIN
	_panel.offset_left = -MARGIN - side
	_panel.queue_redraw()

# 無副作用載入鄰圖並快取（含 null）。供 WorldStitch 的 loader 用。
func _peek_cached(id: String) -> MapData:
	if not _map_cache.has(id):
		_map_cache[id] = MapManager.peek_map(id)
	return _map_cache[id]

# 面板邊長（含 pad）。純、可測。
static func panel_side() -> float:
	return (2 * RADIUS + 1) * CELL_PX + PAD * 2

# 全域格 → 面板像素左上角（隊伍 center 恆落在視窗正中）。純、可測。
static func cell_top_left(global: Vector2i, center: Vector2i) -> Vector2:
	return Vector2(
		PAD + (global.x - (center.x - RADIUS)) * CELL_PX,
		PAD + (global.y - (center.y - RADIUS)) * CELL_PX)

# tile type + 是否 portal → 色塊顏色（portal 旗標優先）。純、可測。
static func tile_color(tile: int, is_portal: bool) -> Color:
	if is_portal:
		return COL_PORTAL
	match tile:
		MapData.TileType.WALL: return COL_WALL
		MapData.TileType.DOOR: return COL_DOOR
		MapData.TileType.STAIRS_UP: return COL_STAIRS_UP
		MapData.TileType.STAIRS_DOWN: return COL_STAIRS_DOWN
		_: return COL_FLOOR

# 內部繪製面板。_draw 在 CanvasItem(Control) 上，讀 autoload + 注入的 loader。
class _MiniMapPanel extends Control:
	var loader: Callable

	func _draw() -> void:
		var map = MapManager.current_map
		if map == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), MiniMap.COL_BACKDROP, true)
		draw_rect(Rect2(Vector2.ZERO, size), MiniMap.COL_BORDER, false, MiniMap.BORDER)
		var center: Vector2i = GameState.player_pos
		var r: int = MiniMap.RADIUS
		var csz: float = MiniMap.CELL_PX - 1
		var placed := WorldStitch.place(map, loader, r, center)
		for node in placed:
			var pm: MapData = node["map"]
			var ox: int = node["ox"]
			var oy: int = node["oy"]
			var explored: Dictionary = GameState.explored_for(pm.map_id)
			for cy in pm.height:
				for cx in pm.width:
					var cell := Vector2i(cx, cy)
					if not explored.has(cell):
						continue
					var gx := ox + cx
					var gy := oy + cy
					if gx < center.x - r or gx > center.x + r or gy < center.y - r or gy > center.y + r:
						continue
					var tl := MiniMap.cell_top_left(Vector2i(gx, gy), center)
					var col := MiniMap.tile_color(pm.get_tile(cell), pm.has_link(cell))
					draw_rect(Rect2(tl.x, tl.y, csz, csz), col, true)
		_draw_player(center)

	func _draw_player(center: Vector2i) -> void:
		var tl := MiniMap.cell_top_left(center, center)
		var c := tl + Vector2(MiniMap.CELL_PX * 0.5, MiniMap.CELL_PX * 0.5)
		var r: float = MiniMap.CELL_PX * 0.42
		var fwd := _facing_vec(GameState.player_facing)
		var side := Vector2(-fwd.y, fwd.x)
		var tip := c + fwd * r
		var bl := c - fwd * r + side * (r * 0.7)
		var br := c - fwd * r - side * (r * 0.7)
		draw_colored_polygon(PackedVector2Array([tip, bl, br]), MiniMap.COL_PLAYER)

	func _facing_vec(facing: int) -> Vector2:
		match facing:
			GridDirection.Dir.EAST: return Vector2(1, 0)
			GridDirection.Dir.SOUTH: return Vector2(0, 1)
			GridDirection.Dir.WEST: return Vector2(-1, 0)
		return Vector2(0, -1)  # NORTH（含預設）：螢幕上方
```

- [ ] **Step 4: 跑聚焦測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_mini_map.gd -gexit`
Expected: PASS（既有 tile_color 2 + 新 4）。

- [ ] **Step 5: 全套測試 + headless 啟動冒煙**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: 全綠、無 fail/parse error（現況 315 + 本計畫新增 peek_map/world_stitch/mini_map 輔助測試）。

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . --quit-after 3`
Expected: 主場景載入無腳本錯誤（特別是無 "Could not find type WorldStitch/MiniMap"、無 nil 存取）後離開。若報 class-not-found，先跑一次編輯器 import 再重試：`"$GODOT" --headless --editor --quit`（`.godot/` gitignored，不改原始碼）；回報是否需要。

- [ ] **Step 6: Commit**

```bash
git add presentation/ui/mini_map.gd tests/presentation/test_mini_map.gd
git commit -m "feat(ui): MiniMap 以隊伍為中心 + 鄰圖拼裝 + 放大 3×（WorldStitch 驅動）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 完成後

- 全套測試綠後，**人工視覺驗收**（待人在顯示器跑 `./run.sh`）：小地圖放大、隊伍恆置中捲動、走近 `wild_nw` 東/南/東南邊界拼出 `wild_ne/wild_sw/wild_se` 已探索格、進 `town_oak`（無鄰）只見城鎮捲動、切圖/讀檔鄰圖快取重建正確。
- 依 `superpowers:finishing-a-development-branch` ff-merge 到 `main`。
- 更新記憶（MEMORY.md / mm3-blobber-build-status.md）：M9b 完成、新增 `engine/map/world_stitch.gd` + `MapManager.peek_map`、小地圖改以隊伍為中心 + 拼裝。
