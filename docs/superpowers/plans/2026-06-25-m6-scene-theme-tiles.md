# M6 場景主題化貼圖 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把場景外觀從寫死在 `world_builder.gd` 的純色 `BoxMesh` 升級成「主題（theme）= 一套 3D 磚塊 kit」的資料驅動管線，讓多張地圖能各自分主題；本里程碑以程式碼生成的 `default` 主題端對端驗證整條管線（零外部素材、保留現有外觀）。

**Architecture:** 沿用三層分離。資料層新增 `DungeonTheme` Resource；地圖 ASCII 加可選 `theme:` header（由 `MapAsciiImporter` 解析）；`ThemeCatalog`（鏡射 `Bestiary`/`ItemCatalog`/`SpellBook`）以 id 解析主題，`default` 由程式碼生成 MeshLibrary。呈現層 `world_builder.gd` 改成驅動**兩個 GridMap**：`FloorGrid`（每個可走格鋪地板）+ `FeatureGrid`（牆/門/階梯在 y0、天花板在 y1）。

**Tech Stack:** Godot 4.7、GDScript、GUT（Godot Unit Test）、內建 GridMap + MeshLibrary。

## 與 spec 的細節調整（規劃階段確認）

1. **兩個 GridMap 取代「單一 GridMap」**：GridMap 一格只能放一個 item，無法在同格同時放「門/階梯方塊」與「其四周的地板」。為保「default 外觀與現況等價」且符合模組化 kit「地板鋪滿 + 特徵疊上」的慣例，拆成 `FloorGrid`（可走格鋪地板）+ `FeatureGrid`（牆/門/階梯/天花板）。
2. **`DungeonTheme.floor_item` 獨立成欄位**：地板鋪在每個可走格（floor 層），`item_for_tile` 只負責 WALL/DOOR/STAIRS 等「特徵」item。語意更清楚、且 kit 的門/階梯零件不必自帶地板。

兩點皆為實作層細節，未改變 spec 的資料驅動意圖與不變式。

## Global Constraints

- 引擎/資料層邏輯為純 GDScript（`extends Object`/`Resource`/`RefCounted`），不依賴視覺節點，以利 GUT 單元測試。
- 內容以 id 參照、**不入存檔**；`theme_id` 屬靜態地圖內容，存檔仍只記 `map_id`（save schema 不變）。
- 不變式：加一張地圖/一個主題 = 加資料檔（地圖 ASCII、`DungeonTheme.tres`、MeshLibrary、`ThemeCatalog._THEMES` 一行），不碰引擎層。
- 不變式：切到 GridMap 後 `default` 主題外觀與現況等價。
- 全程 TDD：先寫失敗測試 → 跑到失敗 → 最小實作 → 跑到通過 → commit。
- **GUT 執行**：全套 `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`；聚焦單檔在該指令尾端加 `-gselect=<test_file.gd>`。
- **新增 `class_name` 全域型別後**若測試報 `Identifier "..." not declared`，先跑一次 `godot --headless --path . --import` 讓 Godot 註冊新 class，再重跑測試。
- 每個 commit 訊息結尾加上：`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`（下方各 Task 的 commit 訊息為精簡示意，executor 須補上此行）。
- 分支：本里程碑在 `m6-scene-theme-tiles` 分支上進行（設計與計畫文件已於此分支 commit）。

---

## File Structure

**新增**
- `resources/dungeon_theme.gd` — `DungeonTheme` Resource（主題資料：mesh_library、floor_item、item_for_tile、ceiling）。
- `presentation/world/theme_catalog.gd` — `ThemeCatalog`：id→主題；`default` 程式碼生成 MeshLibrary。
- `content/themes/.gitkeep`、`content/themes/README.md` — 主題/ kit 存放處與「如何接 kit」步驟。

**修改**
- `resources/map_data.gd` — 加 `theme_id` 欄位。
- `engine/map/map_ascii_importer.gd` — 解析開頭 `theme:` 指令、設定 `map.theme_id`。
- `presentation/world/world_builder.gd` — 改寫成驅動 `FloorGrid` + `FeatureGrid`。

**測試**
- `tests/resources/test_map_data.gd` — 加 `theme_id` 預設值測試。
- `tests/engine/map/test_map_ascii_importer.gd` — 加 header 解析測試。
- `tests/resources/test_dungeon_theme.gd`（新）— `DungeonTheme` 預設/賦值。
- `tests/presentation/test_theme_catalog.gd`（新）— default 主題、未知 id 退回、has/all。
- `tests/presentation/test_world_builder.gd` — 改寫成斷言 GridMap cells。

---

## Task 1: MapData.theme_id 欄位

**Files:**
- Modify: `resources/map_data.gd`
- Test: `tests/resources/test_map_data.gd`

**Interfaces:**
- Produces: `MapData.theme_id: String`（預設 `"default"`），供 Task 2 importer 設定、Task 5 world_builder 讀取。

- [ ] **Step 1: Write the failing test**

在 `tests/resources/test_map_data.gd` 檔尾加：

```gdscript
func test_theme_id_defaults_to_default():
	var map := MapData.new()
	assert_eq(map.theme_id, "default")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_map_data.gd -gexit`
Expected: FAIL（`theme_id` 不存在 / 值不符）。

- [ ] **Step 3: Write minimal implementation**

在 `resources/map_data.gd` 的 `@export var encounters` 那一行之後加：

```gdscript
@export var theme_id: String = "default"  # 對應 ThemeCatalog 的主題 id
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_map_data.gd -gexit`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add resources/map_data.gd tests/resources/test_map_data.gd
git commit -m "feat(map): add MapData.theme_id (default \"default\")"
```

---

## Task 2: MapAsciiImporter 解析 theme: header

**Files:**
- Modify: `engine/map/map_ascii_importer.gd`
- Test: `tests/engine/map/test_map_ascii_importer.gd`

**Interfaces:**
- Consumes: `MapData.theme_id`（Task 1）。
- Produces: `MapAsciiImporter.parse(text)` 解析開頭零或多行 `key: value` 指令；認得 `theme:`，其餘忽略；無 header → `theme_id == "default"`。格子解析行為不變。

- [ ] **Step 1: Write the failing test**

在 `tests/engine/map/test_map_ascii_importer.gd` 檔尾加：

```gdscript
func test_theme_header_sets_theme_id():
	var map := MapAsciiImporter.parse("theme: castle\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.theme_id, "castle")
	assert_eq(map.start_pos, Vector2i(1, 1))
	assert_eq(map.get_tile(Vector2i(0, 0)), MapData.TileType.WALL)

func test_no_header_defaults_theme_id():
	var map := MapAsciiImporter.parse("###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.theme_id, "default")

func test_unknown_directive_ignored():
	var map := MapAsciiImporter.parse("name: dungeon\ntheme: cave\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.theme_id, "cave")
	assert_eq(map.width, 3)
	assert_eq(map.height, 3)

func test_empty_theme_value_keeps_default():
	var map := MapAsciiImporter.parse("theme:\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.theme_id, "default")

func test_header_then_encounter_still_parses():
	var map := MapAsciiImporter.parse("theme: cave\n###\n#@g\n###")
	assert_not_null(map)
	assert_eq(map.theme_id, "cave")
	assert_true(map.has_encounter(Vector2i(2, 1)))
	assert_eq(map.start_pos, Vector2i(1, 1))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_map_ascii_importer.gd -gexit`
Expected: FAIL（header 行被當成未知字元或格子，回 null / theme_id 不符）。

- [ ] **Step 3: Write minimal implementation**

在 `engine/map/map_ascii_importer.gd`，把 `parse()` 開頭（取得 `lines` 之後、計算 `height/width` 之前）改成消化指令行，並在 `map` 建立後設 `theme_id`。完整改寫後的 `parse()`：

```gdscript
static func parse(text: String) -> MapData:
	var lines := _to_lines(text)
	if lines.is_empty():
		return null
	var theme_id := "default"
	# 消化開頭的 key: value 指令行（格子行永遠不含 ":"）
	while not lines.is_empty() and _is_directive(lines[0]):
		var directive: String = lines[0]
		lines.remove_at(0)
		var colon := directive.find(":")
		var key := directive.substr(0, colon).strip_edges()
		var value := directive.substr(colon + 1).strip_edges()
		if key == "theme" and value != "":
			theme_id = value
		# 未知指令：忽略（保留未來擴充）
	if lines.is_empty():
		return null
	var height := lines.size()
	var width: int = lines[0].length()
	if width == 0:
		return null
	var tiles := PackedInt32Array()
	tiles.resize(width * height)
	var encounters := {}
	var start_pos := Vector2i(-1, -1)
	for y in height:
		var line: String = lines[y]
		if line.length() != width:
			return null  # 非矩形
		for x in width:
			var ch := line[x]
			var t := _char_to_tile(ch)
			if t == -1:
				if _is_encounter_marker(ch):
					t = MapData.TileType.FLOOR
					encounters[Vector2i(x, y)] = ch
				else:
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
	map.encounters = encounters
	map.start_pos = start_pos
	map.start_facing = GridDirection.Dir.NORTH
	map.theme_id = theme_id
	return map
```

並在檔案中（例如 `_is_encounter_marker` 之後）新增：

```gdscript
# 指令行 = 以一段 [a-z_] 開頭、緊接 ":" 的行（格子行因含 # . @ D < > a-z 而永遠無 ":"）。
static func _is_directive(line: String) -> bool:
	var colon := line.find(":")
	if colon <= 0:
		return false
	for i in colon:
		var c := line[i]
		if not ((c >= "a" and c <= "z") or c == "_"):
			return false
	return true
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_map_ascii_importer.gd -gexit`
Expected: PASS（新測試與原有 8 個測試全綠）。

- [ ] **Step 5: Commit**

```bash
git add engine/map/map_ascii_importer.gd tests/engine/map/test_map_ascii_importer.gd
git commit -m "feat(map): parse optional theme: header in ascii maps"
```

---

## Task 3: DungeonTheme Resource

**Files:**
- Create: `resources/dungeon_theme.gd`
- Test: `tests/resources/test_dungeon_theme.gd`

**Interfaces:**
- Produces: `class_name DungeonTheme extends Resource`，欄位：
  - `theme_id: String = ""`
  - `mesh_library: MeshLibrary`（預設 null）
  - `floor_item: String = "floor"`
  - `item_for_tile: Dictionary = {}`（key = `MapData.TileType`(int)，value = item 名稱(String)）
  - `has_ceiling: bool = false`
  - `ceiling_item: String = ""`

- [ ] **Step 1: Write the failing test**

建立 `tests/resources/test_dungeon_theme.gd`：

```gdscript
extends GutTest

func test_defaults():
	var t := DungeonTheme.new()
	assert_eq(t.theme_id, "")
	assert_null(t.mesh_library)
	assert_eq(t.floor_item, "floor")
	assert_eq(t.item_for_tile, {})
	assert_false(t.has_ceiling)
	assert_eq(t.ceiling_item, "")

func test_fields_assignable():
	var t := DungeonTheme.new()
	t.theme_id = "castle"
	t.item_for_tile = { MapData.TileType.WALL: "wall" }
	t.has_ceiling = true
	t.ceiling_item = "ceiling"
	assert_eq(t.theme_id, "castle")
	assert_eq(t.item_for_tile[MapData.TileType.WALL], "wall")
	assert_true(t.has_ceiling)
	assert_eq(t.ceiling_item, "ceiling")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_dungeon_theme.gd -gexit`
Expected: FAIL（`DungeonTheme` 未定義；可能需先 `--import`）。

- [ ] **Step 3: Write minimal implementation**

建立 `resources/dungeon_theme.gd`：

```gdscript
class_name DungeonTheme
extends Resource

# 一個「主題」= 一套 3D 磚塊 kit。加新主題 = 加一個 .tres（或程式碼生成），不碰引擎層。
@export var theme_id: String = ""
@export var mesh_library: MeshLibrary           # 該主題整套磚塊；null = 程式碼生成主題
@export var floor_item: String = "floor"        # 鋪在每個可走格的地板 item 名稱
@export var item_for_tile: Dictionary = {}      # MapData.TileType(int) -> 特徵 item 名稱(String)
@export var has_ceiling: bool = false           # 是否在可走格上方鋪天花板
@export var ceiling_item: String = ""           # 天花板 item 名稱（has_ceiling 為真時用）
```

若 Step 4 報 `Identifier "DungeonTheme" not declared`，先跑：`godot --headless --path . --import`，再重跑測試。

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_dungeon_theme.gd -gexit`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add resources/dungeon_theme.gd tests/resources/test_dungeon_theme.gd
git commit -m "feat(theme): add DungeonTheme resource schema"
```

---

## Task 4: ThemeCatalog + 程式碼生成 default 主題

**Files:**
- Create: `presentation/world/theme_catalog.gd`
- Test: `tests/presentation/test_theme_catalog.gd`

**Interfaces:**
- Consumes: `DungeonTheme`（Task 3）、`MapData.TileType`。
- Produces: `class_name ThemeCatalog extends Object`，static API：
  - `get_theme(id: String) -> DungeonTheme`（查無或 `"default"` → 程式碼生成 default 主題）
  - `has_theme(id: String) -> bool`
  - `all_ids() -> Array`
- default 主題 `mesh_library` 含 items：`floor` / `wall` / `door` / `stairs_up` / `stairs_down`，`floor_item == "floor"`，`has_ceiling == false`。

- [ ] **Step 1: Write the failing test**

建立 `tests/presentation/test_theme_catalog.gd`：

```gdscript
extends GutTest

func test_default_theme_has_core_items():
	var t := ThemeCatalog.get_theme("default")
	assert_not_null(t)
	assert_eq(t.theme_id, "default")
	assert_eq(t.floor_item, "floor")
	assert_false(t.has_ceiling)
	assert_not_null(t.mesh_library)
	for name in ["floor", "wall", "door", "stairs_up", "stairs_down"]:
		assert_ne(t.mesh_library.find_item_by_name(name), -1, "default lib 應有 item: %s" % name)

func test_item_for_tile_maps_features():
	var t := ThemeCatalog.get_theme("default")
	assert_eq(t.item_for_tile[MapData.TileType.WALL], "wall")
	assert_eq(t.item_for_tile[MapData.TileType.DOOR], "door")
	assert_eq(t.item_for_tile[MapData.TileType.STAIRS_UP], "stairs_up")
	assert_eq(t.item_for_tile[MapData.TileType.STAIRS_DOWN], "stairs_down")
	assert_false(t.item_for_tile.has(MapData.TileType.FLOOR), "地板走 floor_item，不在 item_for_tile")

func test_unknown_id_falls_back_to_default():
	var t := ThemeCatalog.get_theme("does_not_exist")
	assert_not_null(t)
	assert_eq(t.theme_id, "default")

func test_has_theme_and_all_ids_include_default():
	assert_true(ThemeCatalog.has_theme("default"))
	assert_true(ThemeCatalog.all_ids().has("default"))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_theme_catalog.gd -gexit`
Expected: FAIL（`ThemeCatalog` 未定義；可能需先 `--import`）。

- [ ] **Step 3: Write minimal implementation**

建立 `presentation/world/theme_catalog.gd`：

```gdscript
class_name ThemeCatalog
extends Object

# 主題 id → .tres 路徑（鏡射 Bestiary/ItemCatalog/SpellBook）。
# "default" 為程式碼生成主題（保留現有外觀、零外部素材）；kit 主題屬內容期。
const _THEMES := {}

static func has_theme(id: String) -> bool:
	return id == "default" or _THEMES.has(id)

static func all_ids() -> Array:
	var ids: Array = _THEMES.keys()
	ids.append("default")
	return ids

static func get_theme(id: String) -> DungeonTheme:
	if _THEMES.has(id):
		return load(_THEMES[id])
	return _build_default_theme()

static func _build_default_theme() -> DungeonTheme:
	var theme := DungeonTheme.new()
	theme.theme_id = "default"
	theme.floor_item = "floor"
	theme.item_for_tile = {
		MapData.TileType.WALL: "wall",
		MapData.TileType.DOOR: "door",
		MapData.TileType.STAIRS_UP: "stairs_up",
		MapData.TileType.STAIRS_DOWN: "stairs_down",
	}
	theme.has_ceiling = false
	theme.mesh_library = _build_default_mesh_library()
	return theme

# 把現況彩色盒子轉成 MeshLibrary（數值沿用原 world_builder 常數）。
# mesh transform 讓地板頂面在 y=0、牆/門/階梯由 y=0 往上長（搭配 GridMap.cell_center_y=false）。
static func _build_default_mesh_library() -> MeshLibrary:
	var lib := MeshLibrary.new()
	_add_box(lib, "floor", Vector3(2.0, 0.2, 2.0), Vector3(0, -0.1, 0), Color(0.25, 0.25, 0.28))
	_add_box(lib, "wall", Vector3(2.0, 3.0, 2.0), Vector3(0, 1.5, 0), Color(0.5, 0.42, 0.35))
	_add_box(lib, "door", Vector3(1.2, 2.2, 1.2), Vector3(0, 1.1, 0), Color(0.55, 0.32, 0.15))
	_add_box(lib, "stairs_up", Vector3(1.6, 0.4, 1.6), Vector3(0, 0.2, 0), Color(0.2, 0.5, 0.65))
	_add_box(lib, "stairs_down", Vector3(1.6, 0.4, 1.6), Vector3(0, 0.2, 0), Color(0.2, 0.5, 0.65))
	return lib

static func _add_box(lib: MeshLibrary, item_name: String, size: Vector3, offset: Vector3, color: Color) -> void:
	var id := lib.get_last_unused_item_id()
	lib.create_item(id)
	lib.set_item_name(id, item_name)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	lib.set_item_mesh(id, mesh)
	lib.set_item_mesh_transform(id, Transform3D(Basis(), offset))
```

若 Step 4 報 `Identifier "ThemeCatalog" not declared`，先跑：`godot --headless --path . --import`，再重跑測試。

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_theme_catalog.gd -gexit`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add presentation/world/theme_catalog.gd tests/presentation/test_theme_catalog.gd
git commit -m "feat(theme): add ThemeCatalog with code-generated default theme"
```

---

## Task 5: world_builder 改驅動 FloorGrid + FeatureGrid

**Files:**
- Modify: `presentation/world/world_builder.gd`
- Test: `tests/presentation/test_world_builder.gd`（整檔改寫）

**Interfaces:**
- Consumes: `ThemeCatalog.get_theme()`（Task 4）、`DungeonTheme`（Task 3）、`MapData.theme_id`（Task 1）、`GridGeometry.CELL_SIZE`。
- Produces: `WorldBuilder.build(map: MapData, theme: DungeonTheme = null) -> void`（`theme == null` → 由 `ThemeCatalog` 解析）。建立兩個 child GridMap：`FloorGrid`、`FeatureGrid`。可走格在 `FloorGrid` 放 `floor_item`；WALL/DOOR/STAIRS 在 `FeatureGrid` y0 放對應 item；`has_ceiling` 時可走格在 `FeatureGrid` y1 放 `ceiling_item`。
- `build()` 的單參數呼叫（`main.gd` 的 `_ready()` / `_on_loaded()`）行為不變。

- [ ] **Step 1: Write the failing test**

整檔覆寫 `tests/presentation/test_world_builder.gd`：

```gdscript
extends GutTest

func _map(text: String) -> MapData:
	return MapAsciiImporter.parse(text)

func _wb() -> WorldBuilder:
	var wb := WorldBuilder.new()
	add_child_autofree(wb)
	return wb

func test_wall_gets_feature_floor_cell_gets_floor():
	var wb := _wb()
	wb.build(_map("###\n#@#\n###"))
	var lib := ThemeCatalog.get_theme("default").mesh_library
	var floor_id := lib.find_item_by_name("floor")
	var wall_id := lib.find_item_by_name("wall")
	var fgrid: GridMap = wb.get_node("FloorGrid")
	var feat: GridMap = wb.get_node("FeatureGrid")
	# 中央 (1,1) 是地板：FloorGrid 有 floor、FeatureGrid 無特徵
	assert_eq(fgrid.get_cell_item(Vector3i(1, 0, 1)), floor_id)
	assert_eq(feat.get_cell_item(Vector3i(1, 0, 1)), GridMap.INVALID_CELL_ITEM)
	# 角落 (0,0) 是牆：FeatureGrid=wall、FloorGrid 無地板
	assert_eq(feat.get_cell_item(Vector3i(0, 0, 0)), wall_id)
	assert_eq(fgrid.get_cell_item(Vector3i(0, 0, 0)), GridMap.INVALID_CELL_ITEM)

func test_door_and_stairs_get_floor_and_feature():
	var wb := _wb()
	wb.build(_map("@D<>"))  # (0,0)floor (1,0)door (2,0)up (3,0)down
	var lib := ThemeCatalog.get_theme("default").mesh_library
	var fgrid: GridMap = wb.get_node("FloorGrid")
	var feat: GridMap = wb.get_node("FeatureGrid")
	var floor_id := lib.find_item_by_name("floor")
	for x in [0, 1, 2, 3]:
		assert_eq(fgrid.get_cell_item(Vector3i(x, 0, 0)), floor_id, "x=%d 應有地板" % x)
	assert_eq(feat.get_cell_item(Vector3i(1, 0, 0)), lib.find_item_by_name("door"))
	assert_eq(feat.get_cell_item(Vector3i(2, 0, 0)), lib.find_item_by_name("stairs_up"))
	assert_eq(feat.get_cell_item(Vector3i(3, 0, 0)), lib.find_item_by_name("stairs_down"))
	assert_eq(feat.get_cell_item(Vector3i(0, 0, 0)), GridMap.INVALID_CELL_ITEM, "純地板格無特徵")

func test_rebuild_clears_previous_cells():
	var wb := _wb()
	wb.build(_map("###\n#@#\n###"))
	var feat: GridMap = wb.get_node("FeatureGrid")
	var wall_id := ThemeCatalog.get_theme("default").mesh_library.find_item_by_name("wall")
	assert_eq(feat.get_cell_item(Vector3i(0, 0, 0)), wall_id)
	wb.build(_map("...\n.@.\n..."))  # 全地板
	assert_eq(feat.get_cell_item(Vector3i(0, 0, 0)), GridMap.INVALID_CELL_ITEM, "rebuild 應清掉舊牆")

func test_ceiling_placed_when_theme_has_ceiling():
	var wb := _wb()
	var theme := _theme_with_ceiling()
	wb.build(_map("###\n#@#\n###"), theme)
	var feat: GridMap = wb.get_node("FeatureGrid")
	var ceil_id := theme.mesh_library.find_item_by_name("ceiling")
	# 可走格 (1,1) 上方 y=1 應有天花板；牆格 (0,0) 上方無
	assert_eq(feat.get_cell_item(Vector3i(1, 1, 1)), ceil_id)
	assert_eq(feat.get_cell_item(Vector3i(0, 1, 0)), GridMap.INVALID_CELL_ITEM)

func _theme_with_ceiling() -> DungeonTheme:
	var t := DungeonTheme.new()
	t.theme_id = "test_ceiling"
	t.floor_item = "floor"
	t.item_for_tile = { MapData.TileType.WALL: "wall" }
	t.has_ceiling = true
	t.ceiling_item = "ceiling"
	var lib := MeshLibrary.new()
	for name in ["floor", "wall", "ceiling"]:
		var id := lib.get_last_unused_item_id()
		lib.create_item(id)
		lib.set_item_name(id, name)
		lib.set_item_mesh(id, BoxMesh.new())
	t.mesh_library = lib
	return t
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_builder.gd -gexit`
Expected: FAIL（舊 `world_builder` 蓋的是 MeshInstance3D，無 `FloorGrid`/`FeatureGrid` 節點）。

- [ ] **Step 3: Write minimal implementation**

整檔覆寫 `presentation/world/world_builder.gd`：

```gdscript
class_name WorldBuilder
extends Node3D

const WALL_HEIGHT := 3.0

var _floor_grid: GridMap
var _feature_grid: GridMap

# theme 為 null 時由 ThemeCatalog 依 map.theme_id 解析（測試可注入主題）。
func build(map: MapData, theme: DungeonTheme = null) -> void:
	if theme == null:
		theme = ThemeCatalog.get_theme(map.theme_id)
	_ensure_grids()
	_floor_grid.clear()
	_feature_grid.clear()
	for grid in [_floor_grid, _feature_grid]:
		grid.mesh_library = theme.mesh_library
		grid.cell_size = Vector3(GridGeometry.CELL_SIZE, WALL_HEIGHT, GridGeometry.CELL_SIZE)
		grid.cell_center_y = false  # cell y-index j 的原點落在世界 y = j * cell_size.y
	var lib := theme.mesh_library
	var floor_id := lib.find_item_by_name(theme.floor_item)
	var ceiling_id := -1
	if theme.has_ceiling:
		ceiling_id = lib.find_item_by_name(theme.ceiling_item)
	for y in map.height:
		for x in map.width:
			var t := map.get_tile(Vector2i(x, y))
			if t != MapData.TileType.WALL:
				if floor_id != -1:
					_floor_grid.set_cell_item(Vector3i(x, 0, y), floor_id)
				if ceiling_id != -1:
					_feature_grid.set_cell_item(Vector3i(x, 1, y), ceiling_id)
			if theme.item_for_tile.has(t):
				var fid := lib.find_item_by_name(theme.item_for_tile[t])
				if fid != -1:
					_feature_grid.set_cell_item(Vector3i(x, 0, y), fid)

func _ensure_grids() -> void:
	if _floor_grid == null or not is_instance_valid(_floor_grid):
		_floor_grid = GridMap.new()
		_floor_grid.name = "FloorGrid"
		add_child(_floor_grid)
	if _feature_grid == null or not is_instance_valid(_feature_grid):
		_feature_grid = GridMap.new()
		_feature_grid.name = "FeatureGrid"
		add_child(_feature_grid)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_builder.gd -gexit`
Expected: PASS。

> 若 headless 下 GridMap 的 `set_cell_item`/`get_cell_item` 報錯（非預期），改用單一 GridMap + 為 door/stairs 合成 ArrayMesh 的退路；先回報再調整。資料層測試（cell→item 對應）才是正確性閘門，幾何垂直對位於 Task 6 目視微調。

- [ ] **Step 5: Commit**

```bash
git add presentation/world/world_builder.gd tests/presentation/test_world_builder.gd
git commit -m "feat(world): drive GridMap floor/feature layers from DungeonTheme"
```

---

## Task 6: 主題目錄/文件 + 全套測試 + 目視驗證

**Files:**
- Create: `content/themes/.gitkeep`
- Create: `content/themes/README.md`

**Interfaces:**
- Consumes: 全部前置 Task。
- Produces: 主題存放慣例與「如何接 kit」步驟文件；全套 GUT 綠燈；`default` 主題目視等價現況之確認。

- [ ] **Step 1: 建立主題目錄與文件**

建立空檔 `content/themes/.gitkeep`（內容留空）。建立 `content/themes/README.md`：

```markdown
# 場景主題（DungeonTheme）

每張地圖以 ASCII header `theme: <id>` 指定主題；無 header → `default`（程式碼生成，見 `presentation/world/theme_catalog.gd`）。

## 如何加一個 kit 主題

1. 下載 CC0 / CC-BY 模組化 3D kit（建議低多邊形：Kenney、Quaternius、KayKit），把 `.glb`/`.gltf` 放在 `content/themes/<theme>/`。
2. 在 Godot 編輯器把零件組成 **MeshLibrary**，item 命名對齊角色：
   `floor` / `wall` / `door` / `stairs_up` / `stairs_down` /（可選）`ceiling`。
   匯入時正規化縮放成「2×2 footprint、牆高 3、pivot 在底面中心」。
3. 建一個 `DungeonTheme.tres`：填 `theme_id`、指 `mesh_library`、填 `floor_item`、
   `item_for_tile`（WALL/DOOR/STAIRS → item 名稱）、視需要開 `has_ceiling` + `ceiling_item`。
4. 在 `presentation/world/theme_catalog.gd` 的 `_THEMES` 加一行 `"<id>": "res://content/themes/<theme>.tres"`。
5. 在地圖 ASCII 開頭寫 `theme: <id>`。
6. （CC-BY）在 `content/themes/<theme>/ATTRIBUTION.txt` 記來源、作者與授權。
```

- [ ] **Step 2: 跑全套 GUT，確認無回歸**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全綠（含 M6 新測試與既有所有測試）。

- [ ] **Step 3: 開機 smoke + 目視驗證**

Run: `./run.sh --headless`
Expected: 無腳本錯誤、正常開機關閉（boot smoke）。

接著目視：`./run.sh`
Expected: `level01`（無 header → default 主題）外觀與 M6 前等價——地板平面、牆為實心方塊、門/階梯為對應顏色小方塊、可正常走位。
若地板/牆垂直對位有偏差（浮空或陷入），微調 `theme_catalog.gd` 各 `_add_box` 的 `offset.y` 或 `world_builder.gd` 的 `cell_center_y`，重跑 Step 2/3 直到等價。

- [ ] **Step 4: Commit**

```bash
git add content/themes/.gitkeep content/themes/README.md
git commit -m "docs(theme): add themes dir and kit-authoring guide"
```

> 目視微調若動到程式碼，與本 commit 分開、用 `fix(world)` / `fix(theme)` 訊息各自提交。

---

## Self-Review（規劃者自查）

**Spec 覆蓋**
- 主題以 ASCII `theme:` header 宣告 → Task 2 ✅
- `MapData.theme_id`（不入存檔）→ Task 1 ✅（save schema 未動）
- `DungeonTheme` Resource → Task 3 ✅
- `ThemeCatalog`（鏡射既有 catalog）+ 程式碼生成 default → Task 4 ✅
- `world_builder` 改驅動 GridMap、保留現有外觀 → Task 5 + Task 6 目視 ✅
- 天花板（`has_ceiling`/`ceiling_item`）→ Task 5 測試 ✅
- 「如何接 kit」文件 → Task 6 ✅
- 測試策略（importer / MapData / ThemeCatalog 可單元測試；GridMap 手動）→ 各 Task ✅

**Placeholder 掃描**：無 TBD/TODO；每個 code step 皆有完整程式碼與預期輸出。

**型別一致性**：`build(map, theme=null)`、`floor_item`、`item_for_tile`、`has_ceiling`、`ceiling_item`、節點名 `FloorGrid`/`FeatureGrid`、`GridMap.INVALID_CELL_ITEM`、`find_item_by_name` 跨 Task 一致。
