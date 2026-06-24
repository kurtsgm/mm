# M2「資料驅動地圖」Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 M1 寫死的 `TestMap` 換成資料驅動：純文字檔畫地圖 → `MapAsciiImporter` 解析成 `MapData` Resource → `MapBuilder` 產生走位用的 `GridData`、`WorldBuilder` 依 tile 型別產生幾何，遊戲改由 `MapManager` 從 `content/maps/level01.txt` 載入。

**Architecture:** 三層分離。新增的純邏輯（`MapData` 資料、`MapAsciiImporter` 解析、`MapBuilder` 轉 `GridData`）全部 GUT 單元測試（TDD）；既有引擎四檔（`GridDirection`/`GridData`/`GridMovement`/`GridGeometry`）完全不動。`MapManager` 是薄 autoload，邏輯全委派給純類別。`WorldBuilder` 改吃 `MapData` 並順手修掉 carry-over（`queue_free` → 同步 `free`）。本里程碑**不**碰 `GridMap`/`MeshLibrary`、**不**做樓梯換圖。

**Tech Stack:** Godot 4.7（GL Compatibility）、GDScript、GUT 9.x。

## Global Constraints

- 引擎語言一律 **GDScript**（不混 C#）。
- 引擎層（`res://engine/`）**不得**直接依賴 Godot 視覺節點（`Node3D`、`Camera3D`、`MeshInstance3D` 等）；只能用純資料型別。`MapManager` 是唯一的服務型 autoload，extends `Node`（非視覺節點），放在 `res://autoload/`，邏輯全委派給純類別。
- **既有引擎四檔不得修改**：`engine/grid/grid_direction.gd`、`grid_data.gd`、`grid_movement.gd`、`grid_geometry.gd`。M2 是純加法 + 呈現層改接線。
- 渲染後端固定 **GL Compatibility**（不改 `project.godot` 的 rendering 區段）。
- 格子座標約定：`Vector2i(x, y)`，東為 +x、南為 +y、北為 -y。方向 enum `NORTH=0, EAST=1, SOUTH=2, WEST=3`。世界映射 `CELL_SIZE = 2.0`（沿用 `GridGeometry`）。
- **Tile 型別固定**：`enum TileType { FLOOR = 0, WALL = 1, DOOR = 2, STAIRS_UP = 3, STAIRS_DOWN = 4 }`。tile 陣列列優先，`index = y * width + x`。界外一律視為 `WALL`。
- **ASCII 字元集固定**：`#`=WALL、`.`=FLOOR、`D`=DOOR、`<`=STAIRS_UP、`>`=STAIRS_DOWN、`@`=起點（該格為 FLOOR 並記錄 `start_pos`，起始面向預設 `NORTH`）。
- **可走規則單一出處**：只有 `MapBuilder.is_walkable_type()` 定義型別→可走（`WALL` 擋，其餘可走）。
- `MapAsciiImporter.parse()` 為純函式：合法→回傳 `MapData`；任何違規（空、非矩形、未知字元、零個或多個 `@`）→回傳 `null`，不做任何 log 副作用。
- 每完成一個 Task 就 commit 一次。commit message 用 `feat:` / `test:` / `chore:` 前綴。每個 commit 用 `git add -A`（專案 `.gitignore` 已排除 `.godot/`；`.gd.uid` 應一併入版控）。

**測試指令（每個 Task 都用這條跑全測試）：**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

若出現 `Identifier "MapData"/"MapAsciiImporter"/"MapBuilder" not declared`，表示新 `class_name` 尚未註冊，先跑一次 `godot --headless --path . --import` 再重跑測試。

---

### Task 1：`MapData`（地圖資料 Resource，TDD）

純資料 Resource，存一張地圖的尺寸、tile 陣列、起點與起始面向，並定義 `TileType` enum。提供界外安全的 `get_tile` accessor。

**Files:**
- Create: `resources/map_data.gd`
- Test: `tests/resources/test_map_data.gd`

**Interfaces:**
- Consumes：無（`start_facing` 預設值用 `GridDirection.Dir.NORTH = 0`，但不強制依賴）。
- Produces：`class_name MapData extends Resource`，含：
  - `enum TileType { FLOOR = 0, WALL = 1, DOOR = 2, STAIRS_UP = 3, STAIRS_DOWN = 4 }`
  - `@export var map_id: String`、`width: int`、`height: int`、`tiles: PackedInt32Array`、`start_pos: Vector2i`、`start_facing: int`
  - `func get_tile(pos: Vector2i) -> int`（界外回傳 `TileType.WALL`）

- [ ] **Step 1：寫失敗測試 `tests/resources/test_map_data.gd`**

```gdscript
extends GutTest

func test_dimensions_and_get_tile():
	var map := MapData.new()
	map.width = 3
	map.height = 2
	map.tiles = PackedInt32Array([
		MapData.TileType.WALL, MapData.TileType.FLOOR, MapData.TileType.DOOR,
		MapData.TileType.FLOOR, MapData.TileType.STAIRS_UP, MapData.TileType.WALL,
	])
	assert_eq(map.width, 3)
	assert_eq(map.height, 2)
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(1, 0)), MapData.TileType.FLOOR)
	assert_eq(map.get_tile(Vector2i(2, 0)), MapData.TileType.DOOR)
	assert_eq(map.get_tile(Vector2i(1, 1)), MapData.TileType.STAIRS_UP)

func test_out_of_bounds_is_wall():
	var map := MapData.new()
	map.width = 2
	map.height = 2
	map.tiles = PackedInt32Array([0, 0, 0, 0])  # 全 FLOOR
	assert_eq(map.get_tile(Vector2i(-1, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(2, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(0, 2)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.FLOOR)
```

- [ ] **Step 2：跑測試確認失敗**

Run（見 Global Constraints 的測試指令）。
Expected：FAIL，`Identifier "MapData" not declared`（必要時先 `--import`）。

- [ ] **Step 3：寫最小實作 `resources/map_data.gd`**

```gdscript
class_name MapData
extends Resource

enum TileType { FLOOR = 0, WALL = 1, DOOR = 2, STAIRS_UP = 3, STAIRS_DOWN = 4 }

@export var map_id: String
@export var width: int
@export var height: int
@export var tiles: PackedInt32Array
@export var start_pos: Vector2i
@export var start_facing: int  # GridDirection.Dir；0 = NORTH

func get_tile(pos: Vector2i) -> int:
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return TileType.WALL
	return tiles[pos.y * width + pos.x]
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。
Expected：本檔 2 個測試全 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add MapData resource with tile types and get_tile"
```

---

### Task 2：`MapAsciiImporter`（文字地圖解析，TDD）

純邏輯。把 ASCII 文字解析成 `MapData`；任何違規回傳 `null`（不 log）。這是地圖編寫的入口。

**Files:**
- Create: `engine/map/map_ascii_importer.gd`
- Test: `tests/engine/map/test_map_ascii_importer.gd`

**Interfaces:**
- Consumes：`MapData`（建構與欄位）、`GridDirection.Dir.NORTH`（起始面向）。
- Produces：`class_name MapAsciiImporter extends Object`，含：
  - `static func parse(text: String) -> MapData`（合法回傳 `MapData`，違規回傳 `null`）

- [ ] **Step 1：寫失敗測試 `tests/engine/map/test_map_ascii_importer.gd`**

```gdscript
extends GutTest

func test_parse_simple_map():
	var map := MapAsciiImporter.parse("###\n#@.\n###")
	assert_not_null(map)
	assert_eq(map.width, 3)
	assert_eq(map.height, 3)
	assert_eq(map.start_pos, Vector2i(1, 1))
	assert_eq(map.start_facing, GridDirection.Dir.NORTH)
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.WALL)
	assert_eq(map.get_tile(Vector2i(1, 1)), MapData.TileType.FLOOR)  # @ 是地板
	assert_eq(map.get_tile(Vector2i(2, 1)), MapData.TileType.FLOOR)

func test_parse_all_tile_types():
	var map := MapAsciiImporter.parse("@D<>")
	assert_not_null(map)
	assert_eq(map.width, 4)
	assert_eq(map.height, 1)
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.FLOOR)
	assert_eq(map.get_tile(Vector2i(1, 0)), MapData.TileType.DOOR)
	assert_eq(map.get_tile(Vector2i(2, 0)), MapData.TileType.STAIRS_UP)
	assert_eq(map.get_tile(Vector2i(3, 0)), MapData.TileType.STAIRS_DOWN)

func test_trims_trailing_blank_lines_and_whitespace():
	# 開頭空行要丟掉；"#@  " 行尾空白要修掉 → 寬度 2
	var map := MapAsciiImporter.parse("\n##\n#@  \n##\n\n")
	assert_not_null(map)
	assert_eq(map.width, 2)
	assert_eq(map.height, 3)
	assert_eq(map.start_pos, Vector2i(1, 1))

func test_non_rectangular_returns_null():
	assert_null(MapAsciiImporter.parse("###\n#@\n###"))

func test_unknown_char_returns_null():
	assert_null(MapAsciiImporter.parse("@X"))

func test_missing_start_returns_null():
	assert_null(MapAsciiImporter.parse("###\n#.#\n###"))

func test_multiple_start_returns_null():
	assert_null(MapAsciiImporter.parse("@@"))
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。
Expected：FAIL，`Identifier "MapAsciiImporter" not declared`。

- [ ] **Step 3：寫最小實作 `engine/map/map_ascii_importer.gd`**

```gdscript
class_name MapAsciiImporter
extends Object

# 合法 → MapData；任何違規 → null（不做 log 副作用）。
static func parse(text: String) -> MapData:
	var lines := _to_lines(text)
	if lines.is_empty():
		return null
	var height := lines.size()
	var width: int = lines[0].length()
	if width == 0:
		return null
	var tiles := PackedInt32Array()
	tiles.resize(width * height)
	var start_pos := Vector2i(-1, -1)
	for y in height:
		var line: String = lines[y]
		if line.length() != width:
			return null  # 非矩形
		for x in width:
			var ch := line[x]
			var t := _char_to_tile(ch)
			if t == -1:
				return null  # 未知字元
			if ch == "@":
				if start_pos != Vector2i(-1, -1):
					return null  # 多個起點
				start_pos = Vector2i(x, y)
			tiles[y * width + x] = t
	if start_pos == Vector2i(-1, -1):
		return null  # 沒有起點
	var map := MapData.new()
	map.width = width
	map.height = height
	map.tiles = tiles
	map.start_pos = start_pos
	map.start_facing = GridDirection.Dir.NORTH
	return map

# 切行、修掉每行行尾空白（含 \r）、丟掉開頭與結尾的空行。
static func _to_lines(text: String) -> Array:
	var out: Array = []
	for p in text.split("\n"):
		out.append(p.strip_edges(false, true))  # 只修右側（行尾）
	while out.size() > 0 and out[0] == "":
		out.remove_at(0)
	while out.size() > 0 and out[out.size() - 1] == "":
		out.remove_at(out.size() - 1)
	return out

static func _char_to_tile(ch: String) -> int:
	match ch:
		"#": return MapData.TileType.WALL
		".": return MapData.TileType.FLOOR
		"@": return MapData.TileType.FLOOR  # 起點格是地板
		"D": return MapData.TileType.DOOR
		"<": return MapData.TileType.STAIRS_UP
		">": return MapData.TileType.STAIRS_DOWN
		_: return -1
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。
Expected：本檔 7 個測試全 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add MapAsciiImporter parsing text maps to MapData"
```

---

### Task 3：`MapBuilder`（MapData → GridData，TDD）

純邏輯橋接：把 `MapData` 的 tile 型別轉成引擎走位用的 `GridData`（`WALL` 設 solid，其餘可走）。這是唯一掌握「型別→可走」規則的地方。

**Files:**
- Create: `engine/map/map_builder.gd`
- Test: `tests/engine/map/test_map_builder.gd`

**Interfaces:**
- Consumes：`MapData`（`width`/`height`/`get_tile`/`TileType`）、`MapAsciiImporter.parse`（測試用）、`GridData`（`new`/`set_solid`）。
- Produces：`class_name MapBuilder extends Object`，含：
  - `static func is_walkable_type(tile_type: int) -> bool`
  - `static func to_grid_data(map: MapData) -> GridData`

- [ ] **Step 1：寫失敗測試 `tests/engine/map/test_map_builder.gd`**

```gdscript
extends GutTest

func _map(text: String) -> MapData:
	return MapAsciiImporter.parse(text)

func test_walls_solid_others_walkable():
	var grid := MapBuilder.to_grid_data(_map("###\n#@#\n###"))
	assert_eq(grid.width, 3)
	assert_eq(grid.height, 3)
	assert_true(grid.is_solid(Vector2i(0, 0)))
	assert_true(grid.is_solid(Vector2i(1, 0)))
	assert_true(grid.is_walkable(Vector2i(1, 1)))

func test_door_and_stairs_are_walkable():
	var grid := MapBuilder.to_grid_data(_map("@D<>"))
	assert_true(grid.is_walkable(Vector2i(0, 0)))  # floor
	assert_true(grid.is_walkable(Vector2i(1, 0)))  # door
	assert_true(grid.is_walkable(Vector2i(2, 0)))  # stairs up
	assert_true(grid.is_walkable(Vector2i(3, 0)))  # stairs down

func test_is_walkable_type():
	assert_false(MapBuilder.is_walkable_type(MapData.TileType.WALL))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.FLOOR))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.DOOR))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.STAIRS_UP))
	assert_true(MapBuilder.is_walkable_type(MapData.TileType.STAIRS_DOWN))
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。
Expected：FAIL，`Identifier "MapBuilder" not declared`。

- [ ] **Step 3：寫最小實作 `engine/map/map_builder.gd`**

```gdscript
class_name MapBuilder
extends Object

static func is_walkable_type(tile_type: int) -> bool:
	return tile_type != MapData.TileType.WALL

static func to_grid_data(map: MapData) -> GridData:
	var grid := GridData.new(map.width, map.height)
	for y in map.height:
		for x in map.width:
			var pos := Vector2i(x, y)
			if not is_walkable_type(map.get_tile(pos)):
				grid.set_solid(pos, true)
	return grid
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。
Expected：本檔 3 個測試全 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add MapBuilder converting MapData to walkability GridData"
```

---

### Task 4：`MapManager`（薄 autoload 載入服務，TDD + 註冊）

薄協調層：持有當前 `MapData` 與衍生的 `GridData`，提供從文字／檔案載入的方法；邏輯全委派給 `MapAsciiImporter` 與 `MapBuilder`。註冊成 autoload 供呈現層取用。測試用 preload 直接實例化腳本，不依賴 autoload 單例。

**Files:**
- Create: `autoload/map_manager.gd`
- Test: `tests/autoload/test_map_manager.gd`
- Modify: `project.godot`（新增 `[autoload]` 區段）

**Interfaces:**
- Consumes：`MapAsciiImporter.parse`、`MapBuilder.to_grid_data`、`MapData`、`GridData`。
- Produces：autoload 單例 `MapManager`（路徑 `res://autoload/map_manager.gd`，**無 `class_name`** 以免與 autoload 名稱衝突），含：
  - `var current_map: MapData`、`var current_grid: GridData`
  - `func load_text(text: String) -> MapData`
  - `func load_text_file(path: String) -> MapData`

- [ ] **Step 1：寫失敗測試 `tests/autoload/test_map_manager.gd`**

```gdscript
extends GutTest

const MapManagerScript := preload("res://autoload/map_manager.gd")

func test_load_text_sets_current_map_and_grid():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.load_text("###\n#@#\n###")
	assert_not_null(map)
	assert_eq(mm.current_map, map)
	assert_eq(mm.current_grid.width, 3)
	assert_eq(mm.current_grid.height, 3)
	assert_true(mm.current_grid.is_solid(Vector2i(0, 0)))
	assert_true(mm.current_grid.is_walkable(Vector2i(1, 1)))
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。
Expected：FAIL，`Could not load resource ... res://autoload/map_manager.gd`（檔案還不存在）。

- [ ] **Step 3：寫最小實作 `autoload/map_manager.gd`**

```gdscript
extends Node
# Autoload 單例 "MapManager"：持有當前地圖與衍生走位格。
# 故意不給 class_name，避免與 autoload 名稱衝突。

var current_map: MapData
var current_grid: GridData

func load_text(text: String) -> MapData:
	var map := MapAsciiImporter.parse(text)
	assert(map != null, "MapManager.load_text: invalid map text")
	_set_current(map)
	return map

func load_text_file(path: String) -> MapData:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "MapManager.load_text_file: cannot read %s" % path)
	return load_text(text)

func _set_current(map: MapData) -> void:
	current_map = map
	current_grid = MapBuilder.to_grid_data(map)
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。
Expected：本檔 1 個測試 PASS、`0 failed`。

- [ ] **Step 5：把 `MapManager` 註冊成 autoload**

編輯 `project.godot`，在 `[editor_plugins]` 區段之後、`[input]` 區段之前插入：

```ini
[autoload]

MapManager="*res://autoload/map_manager.gd"
```

（`*` 前綴表示啟用。保留所有既有區段不動。）

- [ ] **Step 6：重新匯入並確認專案無腳本錯誤**

```bash
godot --headless --path . --import
```

Expected：指令結束、無紅色腳本錯誤。再跑一次測試指令，確認整套仍全綠。

- [ ] **Step 7：Commit**

```bash
git add -A && git commit -m "feat: add MapManager autoload loading maps from text"
```

---

### Task 5：呈現層切換到資料驅動地圖（含 carry-over 修正、刪 TestMap，手動驗證）

把呈現層從寫死的 `TestMap` 切到 `content/maps/level01.txt`：改寫 `WorldBuilder` 改吃 `MapData`、依型別畫 地板/牆/門/樓梯、並把清子節點從延遲 `queue_free()` 改成同步 `free()`（carry-over 修正）；改接 `main.gd` 與預覽場景；刪掉 `TestMap`。這是一個原子化的「切換」交付物（單一 commit 後場景仍可執行）。

**Files:**
- Create: `content/maps/level01.txt`
- Modify: `presentation/world/world_builder.gd`（整檔改寫）
- Modify: `tests/presentation/test_world_builder.gd`（整檔改寫）
- Modify: `presentation/world/main.gd`
- Modify: `presentation/world/world_builder_preview.gd`
- Delete: `content/maps/test_map.gd`（及其 `.uid`）

**Interfaces:**
- Consumes：`MapData`、`MapAsciiImporter.parse`、`MapManager`（autoload 單例）、`GridGeometry`（`CELL_SIZE`/`cell_to_world`）、`PlayerController.setup`。
- Produces：`class_name WorldBuilder extends Node3D`，`func build(map: MapData) -> void`（地板一片 + 每個非地板格一個方塊）。

- [ ] **Step 1：改寫失敗測試 `tests/presentation/test_world_builder.gd`（整檔取代）**

```gdscript
extends GutTest

func _map(text: String) -> MapData:
	return MapAsciiImporter.parse(text)

func test_builds_floor_plus_one_box_per_nonfloor_tile():
	# 3x3 外圈牆、中央 @ 地板 → 非地板 8 格
	var wb := WorldBuilder.new()
	add_child_autofree(wb)
	wb.build(_map("###\n#@#\n###"))
	assert_eq(wb.get_child_count(), 8 + 1, "1 floor + 8 wall boxes")

func test_door_and_stairs_each_add_one_box():
	var wb := WorldBuilder.new()
	add_child_autofree(wb)
	wb.build(_map("@D<>"))  # floor, door, stairs_up, stairs_down → 非地板 3
	assert_eq(wb.get_child_count(), 3 + 1, "door+up+down = 3 boxes + 1 floor")

func test_rebuild_clears_previous_geometry():
	var wb := WorldBuilder.new()
	add_child_autofree(wb)
	wb.build(_map("###\n#@#\n###"))     # 1 floor + 8 walls
	assert_eq(wb.get_child_count(), 9)
	wb.build(_map("...\n.@.\n..."))     # 全地板 → 0 牆
	assert_eq(wb.get_child_count(), 1, "rebuild 必須同步清掉舊方塊，只剩地板")
```

- [ ] **Step 2：跑測試確認失敗（只跑此檔，避免受切換中途的 `main.gd` 影響）**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_world_builder.gd -gexit
```

Expected：FAIL／ERROR——舊 `WorldBuilder.build` 參數型別是 `GridData`，傳入 `MapData` 不相容（或 `_map` 取得的 MapData 無法被舊 build 接受）。

- [ ] **Step 3：整檔改寫 `presentation/world/world_builder.gd`**

```gdscript
class_name WorldBuilder
extends Node3D

const WALL_HEIGHT := 3.0
const DOOR_HEIGHT := 2.2
const STAIRS_HEIGHT := 0.4

func build(map: MapData) -> void:
	_clear()
	_build_floor(map)
	_build_tiles(map)

# carry-over 修正：同步移除並釋放，避免同幀 rebuild 殘留舊幾何。
func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

func _build_floor(map: MapData) -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(map.width * GridGeometry.CELL_SIZE, 0.2, map.height * GridGeometry.CELL_SIZE)
	var mi := MeshInstance3D.new()
	mi.mesh = floor_mesh
	var cx := (map.width - 1) * GridGeometry.CELL_SIZE / 2.0
	var cz := (map.height - 1) * GridGeometry.CELL_SIZE / 2.0
	mi.position = Vector3(cx, -0.1, cz)
	mi.material_override = _make_material(Color(0.25, 0.25, 0.28))
	add_child(mi)

func _build_tiles(map: MapData) -> void:
	for y in map.height:
		for x in map.width:
			var pos := Vector2i(x, y)
			match map.get_tile(pos):
				MapData.TileType.WALL:
					_add_box(pos, WALL_HEIGHT, Color(0.5, 0.42, 0.35), 1.0)
				MapData.TileType.DOOR:
					_add_box(pos, DOOR_HEIGHT, Color(0.55, 0.32, 0.15), 0.6)
				MapData.TileType.STAIRS_UP, MapData.TileType.STAIRS_DOWN:
					_add_box(pos, STAIRS_HEIGHT, Color(0.2, 0.5, 0.65), 0.8)
				_:
					pass  # FLOOR：不額外加幾何

func _add_box(pos: Vector2i, height: float, color: Color, footprint: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(GridGeometry.CELL_SIZE * footprint, height, GridGeometry.CELL_SIZE * footprint)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_material(color)
	var world := GridGeometry.cell_to_world(pos)
	mi.position = Vector3(world.x, height / 2.0, world.z)
	add_child(mi)

func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
```

- [ ] **Step 4：跑測試確認通過（只跑此檔）**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_world_builder.gd -gexit
```

Expected：`test_world_builder.gd` 3 個測試全 PASS。（整套全綠留待 Step 9，待 `main.gd`/預覽改接完成後一次驗。）

- [ ] **Step 5：建立 `content/maps/level01.txt`**

內容如下（7×7，重現 M1 佈局；把 M1 的 (3,1) 牆改成門以示範可穿過，並放上下樓梯各一）：

```
#######
#@.D.<#
#..#..#
#..#..#
#....##
#.#..>#
#######
```

注意：檔案只含上述 7 行純文字，不要有額外縮排或結尾多餘空白行（importer 會修掉結尾空行，但保持乾淨）。

- [ ] **Step 6：改接 `presentation/world/main.gd`（整檔取代）**

```gdscript
extends Node3D

const MAP_PATH := "res://content/maps/level01.txt"

@onready var _world_builder: WorldBuilder = $WorldBuilder
@onready var _player: PlayerController = $PlayerController

func _ready() -> void:
	var map := MapManager.load_text_file(MAP_PATH)
	_world_builder.build(map)
	_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)
```

- [ ] **Step 7：改接 `presentation/world/world_builder_preview.gd`（整檔取代）**

```gdscript
extends Node3D

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://content/maps/level01.txt")
	($WorldBuilder as WorldBuilder).build(MapAsciiImporter.parse(text))
```

- [ ] **Step 8：刪除 `TestMap` 並確認無殘留引用**

```bash
git rm content/maps/test_map.gd
rm -f content/maps/test_map.gd.uid
grep -rn "TestMap" --include=*.gd --include=*.tscn .
```

Expected：`grep` 無任何輸出（已無 `TestMap` 引用）。

- [ ] **Step 9：重新匯入並跑全測試**

```bash
godot --headless --path . --import
```

接著跑測試指令。
Expected：整套 GUT 全綠、`0 failed`、無紅色腳本錯誤。

- [ ] **Step 10：手動驗證（操作）**

執行專案（編輯器按 ▶，或 `godot --path .`）。逐項確認：
- [ ] 開場是第一人稱、站在起點 (1,1)、面向北方（看向走廊）。
- [ ] 看得到一片地板、外圈一整圈牆。
- [ ] (3,1) 是一道**矮一截、不同顏色**的門，可以走過去（不被擋）。
- [ ] (5,1) 與 (5,5) 各有一個**地板上的藍色標記**（樓梯），可以走上去（M2 不換圖）。
- [ ] 朝牆前進被擋、不穿牆；走位補間平滑、手感同 M1。
- [ ] 主控台無紅色錯誤。

- [ ] **Step 11：Commit**

```bash
git add -A && git commit -m "feat: data-driven map loading via level01.txt, drop TestMap (M2 complete)"
```

---

## M2 完成定義（Definition of Done）

- 全引擎層測試綠燈（既有 + 新增 `MapData` / `MapAsciiImporter` / `MapBuilder` / `MapManager`），指令列可重現。
- 遊戲從 `content/maps/level01.txt` 載入 → 畫出 地板/牆/門/樓梯 placeholder → 走位手感同 M1（牆擋下、門與樓梯可走）。
- `WorldBuilder` carry-over 修好（同步 `free`），且有 rebuild 測試證明不殘留。
- 三層分離維持：`engine/` 無視覺節點依賴；既有引擎四檔未改動；`MapData` 是 `Resource`；地圖是資料檔。
- `TestMap` 已刪除、所有引用改接 `level01.txt`。
- 每個 Task 各自 commit。

## 後續（不在 M2）

- `GridMap` + `MeshLibrary` 與真 3D 磚塊素材（內容期）。
- 地圖間樓梯換圖（約 M3 前後）——屆時 `MapManager` 補 `change_map` 與玩家重定位。
- 門的開關／鎖狀態、tile 上的事件與遭遇資料。
