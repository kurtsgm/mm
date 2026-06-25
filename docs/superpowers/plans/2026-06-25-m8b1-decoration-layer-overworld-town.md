# M8b-1 裝飾/物件層 + 野外示意城鎮 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 加一條「在地圖某格放可見 3D 模型」的通用裝飾層，並用它在 `wild_nw` 擺一座示意城鎮（純視覺、踩入口格進 `town_oak`）。

**Architecture:** `entities` 多 `decoration` 型別 → `MapImporter` 解析成 `MapData.decorations`；`DecorationCatalog`（model id→GLB，鏡射 `ThemeCatalog`）；`ObjectLayer`（`Node3D`，`build(map)` 把每個 decoration 生成模型擺到格子世界座標）；`main.gd` 在每個 `WorldBuilder.build` 旁一起 `ObjectLayer.build`，切地圖/載入時跟著重建。

**Tech Stack:** Godot 4.7 + GDScript；GUT 9.7 測試；GLB 由 Godot 直接 import。

## Global Constraints

- 引擎二進位不在 PATH：所有 godot 指令用 `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"`。
- 全套測試：`"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`（現況 291 綠）。聚焦單檔：加 `-gselect=<script_name.gd>`。
- 三層架構：`engine/` 純邏輯、`content/` 資料、`presentation/` Godot 節點。沿用既有 catalog 模式（`Bestiary`/`ItemCatalog`/`ThemeCatalog`）。
- 存檔 schema 不變（v3）；decorations 由靜態地圖載入重建，不序列化。
- commit 訊息結尾：`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`。
- 座標：`GridGeometry.cell_to_world(Vector2i)->Vector3`（y=0、CELL_SIZE=2）；`GridGeometry.facing_to_yaw(int)->float`（= `-facing*PI/2`）；`GridDirection.Dir{NORTH=0,EAST=1,SOUTH=2,WEST=3}`。

---

## File Structure

- **Modify** `resources/map_data.gd` — 加 `decorations: Array` 欄位。
- **Modify** `engine/map/map_importer.gd` — `_parse_entities` 加 `decoration` 分支；`parse()` 寫入 `map.decorations`。
- **Create** `presentation/world/decoration_catalog.gd` — model id → GLB 路徑的靜態目錄。
- **Create** `presentation/world/object_layer.gd` — `Node3D`，`build(map, catalog=null)` 生成/重建裝飾模型。
- **Modify** `presentation/world/main.gd` — 建 `ObjectLayer`、在 4 個 `WorldBuilder.build` 點旁 `ObjectLayer.build`。
- **Create** `tests/presentation/test_decoration_catalog.gd`、`tests/presentation/test_object_layer.gd`。
- **Modify** `tests/engine/map/test_map_importer.gd` — 加 decoration 解析測試。
- **Content（需素材）** `content/models/<id>/<file>.glb`（+ import）；`content/maps/wild_nw.json` 加 decoration entity；`DecorationCatalog._MODELS` 註冊。

---

## Task 1: decoration 解析 → MapData.decorations

**Files:**
- Modify: `resources/map_data.gd`
- Modify: `engine/map/map_importer.gd`
- Test: `tests/engine/map/test_map_importer.gd`

**Interfaces:**
- Produces: `MapData.decorations: Array`，每元素 `{"pos": Vector2i, "model": String, "facing": int, "scale": float}`。
- Consumes: 既有 `MapImporter._parse_pos`、`_is_num`、`_facing_word_to_dir`、`GridDirection.Dir`。

- [ ] **Step 1: 在 test_map_importer.gd 末尾加失敗測試**

```gdscript
func test_decoration_entity_parsed():
	var m := _p({"grid": ["@."], "entities": [
		{"type": "decoration", "pos": [1, 0], "model": "town", "facing": "S", "scale": 2.0}]})
	assert_eq(m.decorations.size(), 1)
	var d = m.decorations[0]
	assert_eq(d["pos"], Vector2i(1, 0))
	assert_eq(d["model"], "town")
	assert_eq(d["facing"], GridDirection.Dir.SOUTH)
	assert_eq(d["scale"], 2.0)

func test_decoration_defaults_facing_north_scale_one():
	var m := _p({"grid": ["@."], "entities": [
		{"type": "decoration", "pos": [1, 0], "model": "town"}]})
	var d = m.decorations[0]
	assert_eq(d["facing"], GridDirection.Dir.NORTH)
	assert_eq(d["scale"], 1.0)

func test_decoration_missing_model_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [{"type": "decoration", "pos": [1, 0]}]}))

func test_decoration_out_of_bounds_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [
		{"type": "decoration", "pos": [9, 9], "model": "town"}]}))

func test_no_decoration_defaults_empty():
	var m := _p({"grid": ["@."]})
	assert_eq(m.decorations.size(), 0)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_importer.gd -gexit`
Expected: FAIL（`m.decorations` 不存在 / size 非預期）。

- [ ] **Step 3: 在 `resources/map_data.gd` 加欄位**

在 `links` 那行之後加：

```gdscript
@export var decorations: Array = []         # [{ pos:Vector2i, model:String, facing:int, scale:float }]
```

- [ ] **Step 4: 在 `engine/map/map_importer.gd` 的 `_parse_entities` 加 decoration 分支**

把 `_parse_entities` 改成（在迴圈前加 `var decorations := []`、在 `match` 加分支、結尾回傳多帶 `decorations`）：

```gdscript
static func _parse_entities(arr, width: int, height: int):
	if typeof(arr) != TYPE_ARRAY:
		return null
	var encounters := {}
	var links := {}
	var decorations := []
	for e in arr:
		if typeof(e) != TYPE_DICTIONARY:
			return null
		if not (e.has("type") and e.has("pos")):
			return null
		var pos = _parse_pos(e["pos"])
		if pos == null:
			return null
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			return null
		match String(e["type"]):
			"monster":
				if not e.has("encounter"):
					return null
				encounters[pos] = String(e["encounter"])
			"portal":
				if not e.has("to"):
					return null
				links[pos] = {"map": String(e["to"]), "entry": String(e.get("entry", "start"))}
			"decoration":
				if not e.has("model"):
					return null
				var facing := GridDirection.Dir.NORTH
				if e.has("facing"):
					facing = _facing_word_to_dir(String(e["facing"]))
				var scale := 1.0
				if e.has("scale"):
					if not _is_num(e["scale"]):
						return null
					scale = float(e["scale"])
				decorations.append({"pos": pos, "model": String(e["model"]), "facing": facing, "scale": scale})
			_:
				return null
	return {"encounters": encounters, "links": links, "decorations": decorations}
```

- [ ] **Step 5: 在 `parse()` 寫入 `map.decorations`**

在 `map.links = entities["links"]` 之後加一行：

```gdscript
	map.decorations = entities["decorations"]
```

- [ ] **Step 6: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_importer.gd -gexit`
Expected: PASS（含 5 個新測試；既有 `test_unknown_entity_type_returns_null` 仍綠，因 `chest` 仍非 `decoration`）。

- [ ] **Step 7: Commit**

```bash
git add resources/map_data.gd engine/map/map_importer.gd tests/engine/map/test_map_importer.gd
git commit -m "feat(map): decoration entity 解析成 MapData.decorations

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: DecorationCatalog（model id → GLB 目錄）

**Files:**
- Create: `presentation/world/decoration_catalog.gd`
- Test: `tests/presentation/test_decoration_catalog.gd`

**Interfaces:**
- Produces: `DecorationCatalog.has_model(id: String) -> bool`、`DecorationCatalog.get_scene(id: String) -> PackedScene`（未知 id → null）。
- `const _MODELS := {}`（本任務先空；Task 5 內容期才註冊真模型）。

- [ ] **Step 1: 寫失敗測試** `tests/presentation/test_decoration_catalog.gd`

```gdscript
extends GutTest

func test_unknown_model_has_false_and_null_scene():
	assert_false(DecorationCatalog.has_model("does_not_exist"))
	assert_null(DecorationCatalog.get_scene("does_not_exist"))
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_decoration_catalog.gd -gexit`
Expected: FAIL（`DecorationCatalog` 未定義）。

- [ ] **Step 3: 建 `presentation/world/decoration_catalog.gd`**

```gdscript
class_name DecorationCatalog
extends Object

# model id → GLB（或 .tscn）路徑（鏡射 ThemeCatalog/Bestiary/ItemCatalog）。
# 內容期把真模型加進來：例如 "town_oak_ext": "res://content/models/town_oak_ext/town.glb"。
const _MODELS := {}

static func has_model(id: String) -> bool:
	return _MODELS.has(id)

static func get_scene(id: String) -> PackedScene:
	if _MODELS.has(id):
		return load(_MODELS[id])
	return null
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_decoration_catalog.gd -gexit`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add presentation/world/decoration_catalog.gd tests/presentation/test_decoration_catalog.gd
git commit -m "feat(world): DecorationCatalog（model id → GLB 目錄）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: ObjectLayer（裝飾渲染層）

**Files:**
- Create: `presentation/world/object_layer.gd`
- Test: `tests/presentation/test_object_layer.gd`

**Interfaces:**
- Produces: `ObjectLayer extends Node3D`，`build(map: MapData, catalog = null) -> void`。每個 `map.decorations` 生一個子節點，`position = GridGeometry.cell_to_world(pos)`、`rotation.y = GridGeometry.facing_to_yaw(facing)`、`scale = Vector3.ONE * scale`；重建會先清空舊子節點；`catalog` 為 null 時用 `DecorationCatalog`，否則用注入物件（需有 `get_scene(id)->PackedScene`）。
- Consumes: Task 1 的 `MapData.decorations`；Task 2 的 `DecorationCatalog`；`GridGeometry`。

- [ ] **Step 1: 寫失敗測試** `tests/presentation/test_object_layer.gd`

```gdscript
extends GutTest

class FakeCatalog extends RefCounted:
	var scene: PackedScene
	func get_scene(_id: String) -> PackedScene:
		return scene

func _make_scene() -> PackedScene:
	var root := Node3D.new()
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps

func _map_with(decos: Array) -> MapData:
	var m := MapData.new()
	m.width = 5
	m.height = 5
	m.decorations = decos
	return m

func _deco(pos: Vector2i, facing := GridDirection.Dir.NORTH, scale := 1.0) -> Dictionary:
	return {"pos": pos, "model": "x", "facing": facing, "scale": scale}

func test_build_one_node_per_decoration():
	var layer := ObjectLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_deco(Vector2i(3, 3)), _deco(Vector2i(1, 1))]), cat)
	assert_eq(layer.get_child_count(), 2)

func test_build_positions_and_scales_node():
	var layer := ObjectLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_deco(Vector2i(2, 1), GridDirection.Dir.NORTH, 2.0)]), cat)
	var child: Node3D = layer.get_child(0)
	assert_eq(child.position, GridGeometry.cell_to_world(Vector2i(2, 1)))
	assert_eq(child.scale, Vector3.ONE * 2.0)

func test_build_clears_previous_children():
	var layer := ObjectLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = _make_scene()
	layer.build(_map_with([_deco(Vector2i(0, 0))]), cat)
	layer.build(_map_with([_deco(Vector2i(1, 1))]), cat)
	assert_eq(layer.get_child_count(), 1)

func test_build_skips_unknown_model():
	var layer := ObjectLayer.new()
	add_child_autofree(layer)
	var cat := FakeCatalog.new()
	cat.scene = null
	layer.build(_map_with([_deco(Vector2i(0, 0))]), cat)
	assert_eq(layer.get_child_count(), 0)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_object_layer.gd -gexit`
Expected: FAIL（`ObjectLayer` 未定義）。

- [ ] **Step 3: 建 `presentation/world/object_layer.gd`**

```gdscript
class_name ObjectLayer
extends Node3D

# 把 map.decorations 生成可見模型擺到格子世界座標。切地圖時 build() 會重建。
func build(map: MapData, catalog = null) -> void:
	_clear()
	for deco in map.decorations:
		var scene: PackedScene = null
		if catalog != null:
			scene = catalog.get_scene(deco["model"])
		else:
			scene = DecorationCatalog.get_scene(deco["model"])
		if scene == null:
			continue
		var inst := scene.instantiate()
		add_child(inst)
		if inst is Node3D:
			var n: Node3D = inst
			n.position = GridGeometry.cell_to_world(deco["pos"])
			n.rotation.y = GridGeometry.facing_to_yaw(deco["facing"])
			n.scale = Vector3.ONE * float(deco["scale"])

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_object_layer.gd -gexit`
Expected: PASS（4 個測試）。

- [ ] **Step 5: Commit**

```bash
git add presentation/world/object_layer.gd tests/presentation/test_object_layer.gd
git commit -m "feat(world): ObjectLayer 依 map.decorations 生成/重建裝飾模型

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 接線到 main.gd（切地圖/載入時一起重建）

**Files:**
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes: Task 3 的 `ObjectLayer`。
- 在現有 4 個 `_world_builder.build(...)`（line ~32/130/154/276）旁各加 `_object_layer.build(...)`，傳入同一個 map。

- [ ] **Step 1: 加成員與初始化**

在 `@onready var _world_builder ...` 附近加成員：

```gdscript
var _object_layer: ObjectLayer
```

在 `_ready()` 裡，**緊接在** `_world_builder.build(map)`（line ~32）之前插入建立、之後 build：

```gdscript
	_object_layer = ObjectLayer.new()
	add_child(_object_layer)
	_world_builder.build(map)
	_object_layer.build(map)
```

（即把原本單行 `_world_builder.build(map)` 換成上面四行。）

- [ ] **Step 2: 其餘 3 個重建點各加一行**

每個 `_world_builder.build(MapManager.current_map)` 之後緊接一行：

```gdscript
	_object_layer.build(MapManager.current_map)
```

三處：`_on_*`（link 進圖，line ~130）、`_on_edge_exit_attempted`（line ~154）、`_on_loaded`（line ~276）。

- [ ] **Step 3: headless 開機煙霧測試（無腳本錯誤）**

Run:
```bash
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; ( "$GODOT" --headless --path . 2>&1 & P=$!; sleep 4; kill $P 2>/dev/null; wait $P 2>/dev/null ) | grep -iE "SCRIPT ERROR|Parse Error|object_layer|nonexistent function" | grep -v "Parse JSON failed"
```
Expected: 無輸出（無錯誤）。

- [ ] **Step 4: 全套測試仍綠**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: All tests passed（291 + 本期新增，全綠）。

- [ ] **Step 5: Commit**

```bash
git add presentation/world/main.gd
git commit -m "feat(world): main 在每個世界重建點一起 ObjectLayer.build

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 內容 — 接上示意城鎮模型（需使用者提供 GLB）

> **BLOCKED**：需使用者先下載一個低多邊形卡通 CC0 城堡/城門/小城 GLB 到 `~/Downloads`（Kenney Castle Kit / KayKit Medieval / Quaternius Fantasy Town 擇一）。拿到檔名後才能做。`<id>`/`<glb>` 依實際素材填。

**Files:**
- Create: `content/models/<id>/<glb>`（+ Godot 產生的 `.import`）
- Modify: `presentation/world/decoration_catalog.gd`（註冊 `_MODELS`）
- Modify: `content/maps/wild_nw.json`（加 decoration entity）
- Modify: `tests/presentation/test_decoration_catalog.gd`、`tests/content/test_world_maps.gd`

**Interfaces:**
- Consumes: Task 2 `DecorationCatalog._MODELS`、Task 1 `MapData.decorations`。

- [ ] **Step 1: 放模型並 import**

```bash
mkdir -p content/models/<id>
cp ~/Downloads/<glb> content/models/<id>/
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . --import
```
Expected: import 完成、無 error；產生 `content/models/<id>/<glb>.import`。

- [ ] **Step 2: 在 `_MODELS` 註冊**

`decoration_catalog.gd`：
```gdscript
const _MODELS := {
	"<id>": "res://content/models/<id>/<glb>",
}
```

- [ ] **Step 3: 加 catalog 載入測試**

`tests/presentation/test_decoration_catalog.gd` 末尾加：
```gdscript
func test_registered_model_loads():
	assert_true(DecorationCatalog.has_model("<id>"))
	assert_not_null(DecorationCatalog.get_scene("<id>"))
```

- [ ] **Step 4: 在 wild_nw.json 加 decoration entity**

`content/maps/wild_nw.json` 的 `entities` 陣列加（與現有 portal 並列）：
```json
{ "type": "decoration", "pos": [3, 3], "model": "<id>", "facing": "N", "scale": 1.0 }
```

- [ ] **Step 5: 加地圖斷言測試**

`tests/content/test_world_maps.gd` 末尾加：
```gdscript
func test_wild_nw_has_town_decoration():
	var nw := _load("wild_nw")
	assert_eq(nw.decorations.size(), 1)
	assert_eq(nw.decorations[0]["pos"], Vector2i(3, 3))
	assert_eq(nw.decorations[0]["model"], "<id>")
```

- [ ] **Step 6: 全套測試綠**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: All tests passed。

- [ ] **Step 7: 遊戲內微調 facing/scale 並截圖驗收**

用臨時截圖腳本（建 `wild_nw`、`WorldBuilder.build` + `ObjectLayer.build`、相機俯視玩家起點 (2,2) 與城鎮 (3,3)、存 PNG、`get_tree().quit()`；跑完即刪）。視城鎮朝向/大小調整 wild_nw.json 的 `facing`（N/E/S/W，讓城門朝玩家起點）與 `scale`（約佔 1～2 格），重跑截圖直到外觀 OK。
Expected: 開場 `wild_nw` 在 (3,3) 方向看到一座城鎮。

- [ ] **Step 8: Commit**

```bash
git add content/models/<id> presentation/world/decoration_catalog.gd content/maps/wild_nw.json tests/presentation/test_decoration_catalog.gd tests/content/test_world_maps.gd
git commit -m "feat(content): 野外 wild_nw 擺示意城鎮模型（decoration 層落地）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review 結果

- **Spec coverage**：資料模型(Task1)、匯入(Task1)、DecorationCatalog(Task2)、ObjectLayer(Task3)、main 接線(Task4)、內容/野外城鎮(Task5) — 全部對應到任務。✅
- **Placeholder**：`<id>`/`<glb>` 僅 Task 5（內容相依、素材到位即填），非邏輯缺口；其餘步驟皆有完整程式碼。
- **Type 一致**：`decorations` 元素 dict 鍵 `pos/model/facing/scale` 在 Task1（產生）、Task3（消費）、Task5（斷言）一致；`build(map, catalog=null)`、`get_scene(id)->PackedScene`、`has_model(id)->bool` 跨任務一致。
- **既有測試**：`test_unknown_entity_type_returns_null`（`chest`）不受影響（仍走 `_` → null）。
