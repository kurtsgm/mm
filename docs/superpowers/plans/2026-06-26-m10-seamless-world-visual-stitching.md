# M10 無縫世界視覺拼接 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 渲染目前區域 + 一圈鄰區（含對角）的地形與裝飾，各擺在 WorldStitch 全域偏移，讓野外邊界視覺連續、跨界無重建閃爍；玩法不變。

**Architecture:** 新增 `WorldStitchRenderer`（Node3D），用 M9b 的 `WorldStitch.place` 算出區域環、對每個 placed 區域以容器位移到 `Vector3(ox*CELL_SIZE,0,oy*CELL_SIZE)` 並用既有 `WorldBuilder`+`ObjectLayer` 建內容；以 map_id pooling 重用區域節點。`main.gd` 的 4 個重建點改呼叫 `_world_renderer.rebuild(current_map)`，玩家/轉場邏輯不動（無縫由「鄰區已在位 + 重建即純平移」自然達成）。

**Tech Stack:** Godot 4.7 + GDScript；GUT 9.7 測試；GridMap（既有 WorldBuilder）。

## Global Constraints

- 引擎二進位不在 PATH：所有 godot 指令用 `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"`。
- 全套測試：`"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`（現況 327 綠）。聚焦單檔：加 `-gselect=<script_name.gd>`。
- 三層架構：`engine/` 純邏輯、`autoload/` 全域單例、`presentation/` Godot 節點。
- 重用既有元件、不改其內部：`WorldBuilder.build(map, theme=null)`（依 `map.theme_id` 解析主題，`default` 為程序生成、無外部素材）、`ObjectLayer.build(map)`。
- 座標：`GridGeometry.CELL_SIZE == 2.0`；區域世界偏移 = `Vector3(ox*CELL_SIZE, 0, oy*CELL_SIZE)`，`(ox,oy)` 來自 `WorldStitch.place`。
- 拼裝（M9b 既有）：`WorldStitch.place(origin_map, loader, half, center) -> Array[{map,ox,oy}]`，`MapManager.peek_map(id)->MapData`（無副作用、未知回 null）。
- 渲染集合：`half = max(current.width, current.height)`、`center = Vector2i(current.width/2, current.height/2)`（區域中心、與玩家位置無關）。
- 存檔不變。commit 訊息結尾：`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`。

---

## File Structure

- **Create** `presentation/world/world_stitch_renderer.gd` — `WorldStitchRenderer`：環渲染 + map_id pooling。
- **Create** `tests/presentation/test_world_stitch_renderer.gd` — 拼接/偏移/pooling/重定位 + 真實建構 smoke。
- **Modify** `presentation/world/main.gd` — 移除 `_world_builder`/`_object_layer`，加 `_world_renderer`，4 個重建點改 `rebuild`。
- **Modify** `presentation/world/main.tscn` — 移除 `WorldBuilder` 節點（renderer 內部自建多份）。

---

### Task 1: WorldStitchRenderer（環渲染 + pooling）

**Files:**
- Create: `presentation/world/world_stitch_renderer.gd`
- Test: `tests/presentation/test_world_stitch_renderer.gd` (create)

**Interfaces:**
- Consumes: `WorldStitch.place(origin_map, loader, half, center)`（M9b）、`MapManager.peek_map`（M9b）、`WorldBuilder`/`ObjectLayer`（既有）、`GridGeometry.CELL_SIZE`、`GridDirection.Dir`、`MapData`。
- Produces:
  - `class_name WorldStitchRenderer extends Node3D`
  - `var loader: Callable`（預設 `Callable(MapManager, "peek_map")`）
  - `var region_builder: Callable`（測試 seam；簽章 `func(container: Node3D, map: MapData)`；預設無效 → 建真 WorldBuilder+ObjectLayer）
  - `func rebuild(current_map: MapData) -> void`（算環 → 清離開 → 沿用/新建 + 重定位）

- [ ] **Step 1: 寫失敗測試**

Create `tests/presentation/test_world_stitch_renderer.gd`:

```gdscript
extends GutTest

var _world := {}

func _map(id: String, w: int, h: int, neighbors := {}) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.neighbors = neighbors
	return m

func _loader(id: String) -> MapData:
	return _world.get(id, null)

# 假 region_builder：在容器放一個帶 map_id 名的標記節點，不建真 GridMap。
func _fake_build(container: Node3D, map: MapData) -> void:
	var marker := Node3D.new()
	marker.name = "marker_" + map.map_id
	container.add_child(marker)

func _renderer() -> WorldStitchRenderer:
	var r := WorldStitchRenderer.new()
	r.loader = Callable(self, "_loader")
	r.region_builder = Callable(self, "_fake_build")
	add_child_autofree(r)
	return r

func _container_with_marker(r: WorldStitchRenderer, marker_name: String) -> Node3D:
	for c in r.get_children():
		if c.has_node(marker_name):
			return c
	return null

func test_single_map_one_container_at_origin():
	var a := _map("a", 5, 5)
	_world = { "a": a }
	var r := _renderer()
	r.rebuild(a)
	assert_eq(r.get_child_count(), 1)
	assert_eq((r.get_child(0) as Node3D).position, Vector3.ZERO)

func test_east_neighbor_container_offset():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var r := _renderer()
	r.rebuild(a)
	var e_container := _container_with_marker(r, "marker_e")
	assert_not_null(e_container)
	assert_eq(e_container.position, Vector3(5 * GridGeometry.CELL_SIZE, 0, 0))

func test_pooling_reuses_region_node_across_rebuild():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	_world = { "a": a, "e": e }
	var r := _renderer()
	r.rebuild(a)
	var a1 := _container_with_marker(r, "marker_a")
	r.rebuild(a)   # 同一 current 再 rebuild
	var a2 := _container_with_marker(r, "marker_a")
	assert_eq(a1, a2, "沿用同一節點實例，未重建")

func test_pooling_frees_departed_region():
	var a := _map("a", 5, 5, { GridDirection.Dir.EAST: "e" })
	var e := _map("e", 5, 5, { GridDirection.Dir.WEST: "a" })
	var far := _map("far", 5, 5)
	_world = { "a": a, "e": e, "far": far }
	var r := _renderer()
	r.rebuild(a)
	assert_gt(r.get_child_count(), 1)
	r.rebuild(far)   # far 無鄰 → a/e 應被 free
	assert_eq(r.get_child_count(), 1, "離開的區域被清掉")
	assert_not_null(_container_with_marker(r, "marker_far"))

func test_default_path_builds_real_worldbuilder_and_objectlayer():
	# 不注入 region_builder → 走真實建構（default 程序主題、無外部素材）。
	var a := _map("a", 3, 3)
	a.theme_id = "default"
	var t := PackedInt32Array()
	t.resize(9)        # 全 0 = FLOOR
	a.tiles = t
	_world = { "a": a }
	var r := WorldStitchRenderer.new()
	r.loader = Callable(self, "_loader")
	add_child_autofree(r)
	r.rebuild(a)
	assert_eq(r.get_child_count(), 1)
	var container: Node3D = r.get_child(0)
	assert_eq(container.position, Vector3.ZERO)
	assert_true(container.get_child(0) is WorldBuilder, "容器含 WorldBuilder")
	assert_true(container.get_child(1) is ObjectLayer, "容器含 ObjectLayer")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_world_stitch_renderer.gd -gexit`
Expected: FAIL（`WorldStitchRenderer` 不存在 / 未定義）。若報 class 未定義，先跑一次編輯器 import 再重試：`"$GODOT" --headless --editor --quit`（`.godot/` gitignored）。

- [ ] **Step 3: 實作**

Create `presentation/world/world_stitch_renderer.gd`:

```gdscript
class_name WorldStitchRenderer
extends Node3D
# 渲染目前區域 + 一圈鄰區（含對角）的地形+裝飾，各擺在 WorldStitch 全域偏移。
# 以 map_id pooling 重用已建區域節點：跨界只重定位、只建新露出、只清離開
# （避免每次跨界重新 instantiate 持續存在的重 prop，達成無縫）。
# 目前區域用傳入的 live current_map；鄰區用 loader（peek_map）。

var loader: Callable = Callable(MapManager, "peek_map")
# 測試 seam：func(container: Node3D, map: MapData)。預設無效 → 建真 WorldBuilder+ObjectLayer。
var region_builder: Callable = Callable()

var _regions: Dictionary = {}  # map_id -> Node3D 容器

func rebuild(current_map: MapData) -> void:
	if current_map == null:
		return
	var half: int = max(current_map.width, current_map.height)
	var center := Vector2i(current_map.width / 2, current_map.height / 2)
	var placed := WorldStitch.place(current_map, loader, half, center)
	# 新集合的 id
	var keep := {}
	for node in placed:
		keep[node["map"].map_id] = true
	# 清掉離開的區域
	for id in _regions.keys():
		if not keep.has(id):
			_regions[id].free()
			_regions.erase(id)
	# 沿用/新建 + 重定位（沿用者偏移也會隨目前區域改變）
	for node in placed:
		var m: MapData = node["map"]
		var container: Node3D
		if _regions.has(m.map_id):
			container = _regions[m.map_id]
		else:
			container = Node3D.new()
			add_child(container)
			_regions[m.map_id] = container
			_build_content(container, m)
		container.position = Vector3(
			node["ox"] * GridGeometry.CELL_SIZE, 0.0, node["oy"] * GridGeometry.CELL_SIZE)

func _build_content(container: Node3D, map: MapData) -> void:
	if region_builder.is_valid():
		region_builder.call(container, map)
		return
	var wb := WorldBuilder.new()
	container.add_child(wb)
	wb.build(map)
	var ol := ObjectLayer.new()
	container.add_child(ol)
	ol.build(map)
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_world_stitch_renderer.gd -gexit`
Expected: PASS（5 測）。若報 `WorldStitchRenderer` 未定義，先跑 `"$GODOT" --headless --editor --quit` 再重試。

- [ ] **Step 5: Commit**

```bash
git add presentation/world/world_stitch_renderer.gd tests/presentation/test_world_stitch_renderer.gd
git commit -m "feat(world): WorldStitchRenderer 環渲染鄰區（全域偏移 + map_id pooling）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: main.gd / main.tscn 接線（用 renderer 取代單區建構）

**Files:**
- Modify: `presentation/world/main.gd`
- Modify: `presentation/world/main.tscn`

**Interfaces:**
- Consumes: `WorldStitchRenderer`（Task 1）、`MapManager.current_map`。
- Produces: 遊戲執行時渲染目前+鄰區、跨界視覺連續。整體場景接線，沿用慣例不寫單元測試；以全套綠 + headless boot smoke + 手動 `./run.sh` 驗收。

- [ ] **Step 1: 改 main.tscn（移除 WorldBuilder 節點）**

整檔取代 `presentation/world/main.tscn`：

```
[gd_scene load_steps=3 format=3 uid="uid://c3m1n5w0rldm1"]

[ext_resource type="Script" uid="uid://h57unrnf63d1" path="res://presentation/world/main.gd" id="1_main"]
[ext_resource type="Script" uid="uid://beagnucio0hh" path="res://presentation/world/player_controller.gd" id="3_player"]

[node name="Main" type="Node3D"]
script = ExtResource("1_main")

[node name="PlayerController" type="Node3D" parent="."]
script = ExtResource("3_player")

[node name="Camera3D" type="Camera3D" parent="PlayerController"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 0)

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.642788, -0.766044, 0, 0.766044, 0.642788, 0, 8, 0)
```

（移除了 `WorldBuilder` 節點與其 `ext_resource`，`load_steps` 4→3。`WorldBuilder` 仍經 `class_name` 全域可用，由 renderer 內部 `WorldBuilder.new()` 建立。）

- [ ] **Step 2: 改 main.gd — 宣告**

In `presentation/world/main.gd`:

Remove the `@onready` line (line 16):
```gdscript
@onready var _world_builder: WorldBuilder = $WorldBuilder
```

Replace the `var _object_layer: ObjectLayer` declaration (line 20) with:
```gdscript
var _world_renderer: WorldStitchRenderer
```

- [ ] **Step 3: 改 main.gd — `_ready` 建 renderer**

In `_ready`, replace these four lines (the ObjectLayer creation + both builds):
```gdscript
	_object_layer = ObjectLayer.new()
	add_child(_object_layer)
	_world_builder.build(map)
	_object_layer.build(map)
```
with:
```gdscript
	_world_renderer = WorldStitchRenderer.new()
	add_child(_world_renderer)
	_world_renderer.rebuild(MapManager.current_map)
```

- [ ] **Step 4: 改 main.gd — 其餘 3 個重建點**

In `_enter_via_link`, replace:
```gdscript
	_world_builder.build(MapManager.current_map)
	_object_layer.build(MapManager.current_map)
```
with:
```gdscript
	_world_renderer.rebuild(MapManager.current_map)
```

In `_on_edge_exit_attempted`, replace the same two lines:
```gdscript
	_world_builder.build(MapManager.current_map)
	_object_layer.build(MapManager.current_map)
```
with:
```gdscript
	_world_renderer.rebuild(MapManager.current_map)
```

In `_on_loaded`, replace the same two lines:
```gdscript
	_world_builder.build(MapManager.current_map)
	_object_layer.build(MapManager.current_map)
```
with:
```gdscript
	_world_renderer.rebuild(MapManager.current_map)
```

- [ ] **Step 5: 全套測試 + headless 啟動冒煙**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: 全綠、無 fail/parse error（現況 327 + Task 1 的 renderer 測試）。

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . --quit-after 3`
Expected: 主場景載入、`_ready` 跑 `rebuild` 無腳本錯誤（無 "Could not find type WorldStitchRenderer"、無 nil、無缺 `$WorldBuilder` 報錯）後離開。若報 class-not-found，先跑 `"$GODOT" --headless --editor --quit` 再重試。

- [ ] **Step 6: 手動視覺驗收（`./run.sh`，人工）**

Run: `./run.sh`
逐項確認：
- 開場 `wild_nw` 望向東/南/東南，看到 `wild_ne`/`wild_sw`/`wild_se` 的草地與裝飾（含對角的城鎮 prop 從遠處可見）延伸過去，不是虛空/硬邊界。
- 走到東/南邊界踏過去：畫面連續（像往前走一格）、無黑幕、無重建閃爍。
- 在野外 2×2 來回穿越多次：城堡 prop 不卡頓（pooling 沿用、未重建）。
- 進 `town_oak`（無 neighbors）：只渲染城鎮單區、維持淡入淡出；recall/portal 正常。
- Tab 存檔 → 重開 → 讀檔：世界正確重建。

- [ ] **Step 7: Commit**

```bash
git add presentation/world/main.gd presentation/world/main.tscn
git commit -m "feat(world): main 用 WorldStitchRenderer 渲染目前+鄰區（無縫世界視覺）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 完成後

- 全套測試綠 + `./run.sh` 視覺驗收通過後，依 `superpowers:finishing-a-development-branch` ff-merge 到 `main` 並 push。
- 更新記憶（MEMORY.md / mm3-blobber-build-status.md）：M10 完成、新增 `presentation/world/world_stitch_renderer.gd`、main 改用 renderer 渲染目前+鄰區、跨界視覺無縫。
