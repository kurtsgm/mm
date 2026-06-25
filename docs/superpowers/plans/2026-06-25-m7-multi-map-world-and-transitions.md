# M7 多地圖世界 + 切換 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把單一地圖升級成「多張 `MapData` 互連的世界」，提供邊緣無縫接壤與明確入口連結兩種地圖切換，連結全部宣告在各地圖 `.txt` 的 header。

**Architecture:** 三層分離。資料層 `MapData` 加四個靜態欄位（鄰圖/命名入口/連結/顯示名）；內容層 `MapAsciiImporter` 擴充 header 與大寫標記解析；引擎層新增純邏輯 `MapTransitions`（邊緣偵測/抵達格/連結解析）+ `GridMovement.direction_of`；切換協調由 `MapManager.enter_map`（載入+重套已清遭遇，存讀檔共用）與 `PlayerController.edge_exit_attempted` 訊號驅動；呈現層 `main.gd` 串起轉場（淡出→重建→放隊伍）。

**Tech Stack:** Godot 4.7、GDScript、GUT（Godot Unit Test）。

## Global Constraints

- 引擎/資料層為純邏輯，不依賴視覺節點，採 TDD（GUT）。autoload（`MapManager`/`GameState`/`SaveSystem`）**無 `class_name`**；測試以 `preload("res://autoload/xxx.gd").new()` + `add_child_autofree()` 實例化。
- GDScript 縮排一律用 **tab**（跟齊既有檔）。
- 存檔 schema **不變**：`SaveSerializer.VERSION` 維持 `3`；不新增存檔欄位。`neighbors/entries/links/display_name` 屬靜態內容，載入時由 `MapData` 帶出。
- 加一張地圖 / 連一條路 = 加/改地圖 `.txt`，**不碰引擎層**。
- 方向列舉：`GridDirection.Dir { NORTH=0, EAST=1, SOUTH=2, WEST=3 }`；`to_vector(NORTH)=Vector2i(0,-1)`、`EAST=(1,0)`、`SOUTH=(0,1)`、`WEST=(-1,0)`。
- 邊緣接壤要求共邊維度相同、橫向座標保留、保持面向；對邊格實心則擋住（不切換）。
- 每個 commit 訊息結尾加一行：`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`（下方 commit 步驟為求精簡未每次重列，請一律附上）。
- 測試指令：
  - 單檔：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://<test_path> -gexit`
  - 全套：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`（自動讀 `.gutconfig.json`）

## 檔案結構（本計畫新增/修改）

| 檔案 | 責任 | 動作 |
|------|------|------|
| `resources/map_data.gd` | 地圖資料 + 連結欄位與存取器 | 修改 |
| `engine/map/map_ascii_importer.gd` | ASCII → MapData（header + 標記解析） | 修改 |
| `engine/map/map_transitions.gd` | 純切換邏輯（邊緣/抵達/連結） | 新增 |
| `engine/grid/grid_movement.gd` | 移動 → 世界方向 helper | 修改 |
| `autoload/map_manager.gd` | `enter_map`（載入 + 重套已清遭遇） | 修改 |
| `autoload/save_system.gd` | `apply_to` 改用 `enter_map`（DRY） | 修改 |
| `presentation/world/player_controller.gd` | 出界發 `edge_exit_attempted` 訊號 | 修改 |
| `presentation/world/main.gd` | 轉場串接 + 淡出黑幕 + 起始圖 + town_portal | 修改 |
| `content/maps/wild_{nw,ne,sw,se}.txt`、`town_oak.txt` | 示範世界（2×2 野外 + 城鎮） | 新增 |
| `tests/...` | 對應 GUT 測試 | 新增/修改 |

執行順序：Task 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8。

---

### Task 1: `MapData` 連結欄位與存取器

**Files:**
- Modify: `resources/map_data.gd`
- Test: `tests/resources/test_map_data.gd`

**Interfaces:**
- Consumes: `GridDirection.Dir`（既有）。
- Produces:
  - `MapData.display_name: String`（預設 `""`）
  - `MapData.neighbors: Dictionary` — `int(GridDirection.Dir) -> String(map_id)`
  - `MapData.entries: Dictionary` — `String(name) -> { "pos": Vector2i, "facing": int }`
  - `MapData.links: Dictionary` — `Vector2i(cell) -> { "map": String, "entry": String }`
  - `has_neighbor(dir: int) -> bool`、`get_neighbor(dir: int) -> String`
  - `has_entry(name: String) -> bool`、`get_entry(name: String) -> Dictionary`
  - `has_link(pos: Vector2i) -> bool`、`get_link(pos: Vector2i) -> Dictionary`

- [ ] **Step 1: 寫失敗測試**（附加到 `tests/resources/test_map_data.gd` 檔尾）

```gdscript
func test_world_fields_default_empty():
	var map := MapData.new()
	assert_eq(map.display_name, "")
	assert_eq(map.neighbors, {})
	assert_eq(map.entries, {})
	assert_eq(map.links, {})

func test_neighbor_accessors():
	var map := MapData.new()
	map.neighbors = { GridDirection.Dir.EAST: "east_map" }
	assert_true(map.has_neighbor(GridDirection.Dir.EAST))
	assert_eq(map.get_neighbor(GridDirection.Dir.EAST), "east_map")
	assert_false(map.has_neighbor(GridDirection.Dir.WEST))
	assert_eq(map.get_neighbor(GridDirection.Dir.WEST), "")

func test_entry_accessors():
	var map := MapData.new()
	map.entries = { "gate": {"pos": Vector2i(2, 1), "facing": GridDirection.Dir.SOUTH} }
	assert_true(map.has_entry("gate"))
	assert_eq(map.get_entry("gate"), {"pos": Vector2i(2, 1), "facing": GridDirection.Dir.SOUTH})
	assert_false(map.has_entry("none"))
	assert_eq(map.get_entry("none"), {})

func test_link_accessors():
	var map := MapData.new()
	map.links = { Vector2i(3, 3): {"map": "town_oak", "entry": "gate"} }
	assert_true(map.has_link(Vector2i(3, 3)))
	assert_eq(map.get_link(Vector2i(3, 3)), {"map": "town_oak", "entry": "gate"})
	assert_false(map.has_link(Vector2i(0, 0)))
	assert_eq(map.get_link(Vector2i(0, 0)), {})
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/resources/test_map_data.gd -gexit`
Expected: FAIL（`Invalid set ... 'display_name'` / `Invalid call ... 'has_neighbor'`）

- [ ] **Step 3: 實作**（在 `resources/map_data.gd` 既有 `@export var theme_id` 之後加欄位、檔尾加存取器）

欄位（接在 `@export var theme_id: String = "default"` 下方）：

```gdscript
@export var display_name: String = ""             # 顯示名（切換訊息用），空 → 退回 map_id
@export var neighbors: Dictionary = {}            # int(GridDirection.Dir) -> String(map_id)
@export var entries: Dictionary = {}              # String(name) -> { "pos": Vector2i, "facing": int }
@export var links: Dictionary = {}                # Vector2i(cell) -> { "map": String, "entry": String }
```

存取器（檔尾，比照既有 `has_encounter` 風格）：

```gdscript
func has_neighbor(dir: int) -> bool:
	return neighbors.has(dir)

func get_neighbor(dir: int) -> String:
	return neighbors.get(dir, "")

func has_entry(name: String) -> bool:
	return entries.has(name)

func get_entry(name: String) -> Dictionary:
	return entries.get(name, {})

func has_link(pos: Vector2i) -> bool:
	return links.has(pos)

func get_link(pos: Vector2i) -> Dictionary:
	return links.get(pos, {})
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/resources/test_map_data.gd -gexit`
Expected: PASS（全綠）

- [ ] **Step 5: Commit**

```bash
git add resources/map_data.gd tests/resources/test_map_data.gd && git commit -m "feat(map): add MapData neighbors/entries/links/display_name fields"
```

---

### Task 2: `MapAsciiImporter` header 與大寫標記解析

**Files:**
- Modify: `engine/map/map_ascii_importer.gd`
- Test: `tests/engine/map/test_map_ascii_importer.gd`

**Interfaces:**
- Consumes: Task 1 的 `MapData` 欄位；`GridDirection.Dir`。
- Produces：`parse(text)` 額外填入 `display_name` / `neighbors` / `entries` / `links`；`@` 起點額外寫入 `entries["start"] = {pos: start_pos, facing: NORTH}`。新認得的 header 指令：`name:`、`north:/east:/south:/west:`、`entry <name>: x,y[ N|E|S|W]`、`link <MARKER>: <dest_map>[.<entry>]`；網格上的大寫 A–Z 標記若有對應 `link` 宣告 → 該格為 `FLOOR` 並登記 `links`；無對應宣告的大寫字母 → `parse` 回 `null`。

> 關鍵不變式：合法格子字元為 `# . @ D < > a-z A-Z`，皆**不含 `:`**，故「含 `:` 的行＝指令行」無歧義。本任務據此把 `_is_directive` 簡化為「行內含冒號」，以支援 `entry gate:` / `link T:` 這種帶空白與大寫的 key。

- [ ] **Step 1: 寫失敗測試**（附加到 `tests/engine/map/test_map_ascii_importer.gd` 檔尾）

```gdscript
func test_name_header_sets_display_name():
	var map := MapAsciiImporter.parse("name: 橡鎮\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.display_name, "橡鎮")

func test_neighbor_headers_parsed():
	var map := MapAsciiImporter.parse("north: a\neast: b\nsouth: c\nwest: d\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.get_neighbor(GridDirection.Dir.NORTH), "a")
	assert_eq(map.get_neighbor(GridDirection.Dir.EAST), "b")
	assert_eq(map.get_neighbor(GridDirection.Dir.SOUTH), "c")
	assert_eq(map.get_neighbor(GridDirection.Dir.WEST), "d")

func test_entry_header_with_facing():
	var map := MapAsciiImporter.parse("entry gate: 1,1 S\n###\n#@#\n###")
	assert_not_null(map)
	assert_eq(map.get_entry("gate"), {"pos": Vector2i(1, 1), "facing": GridDirection.Dir.SOUTH})

func test_entry_header_defaults_facing_north():
	var map := MapAsciiImporter.parse("entry spot: 2,0\n###\n#@#\n###")
	assert_eq(map.get_entry("spot"), {"pos": Vector2i(2, 0), "facing": GridDirection.Dir.NORTH})

func test_at_creates_start_entry():
	var map := MapAsciiImporter.parse("###\n#@#\n###")
	assert_eq(map.get_entry("start"), {"pos": Vector2i(1, 1), "facing": GridDirection.Dir.NORTH})

func test_link_marker_is_floor_and_recorded():
	var map := MapAsciiImporter.parse("link T: town_oak.gate\n###\n#@T\n###")
	assert_not_null(map)
	assert_eq(map.get_tile(Vector2i(2, 1)), MapData.TileType.FLOOR)
	assert_true(map.has_link(Vector2i(2, 1)))
	assert_eq(map.get_link(Vector2i(2, 1)), {"map": "town_oak", "entry": "gate"})

func test_link_value_without_entry_defaults_start():
	var map := MapAsciiImporter.parse("link T: town_oak\n###\n#@T\n###")
	assert_eq(map.get_link(Vector2i(2, 1)), {"map": "town_oak", "entry": "start"})

func test_uppercase_without_link_declaration_returns_null():
	# 'Z' 無對應 link 宣告 → 未知字元 → null（嚴格抓打字錯）
	assert_null(MapAsciiImporter.parse("##\n@Z"))

func test_old_map_has_empty_world_fields():
	var map := MapAsciiImporter.parse("###\n#@#\n###")
	assert_eq(map.neighbors, {})
	assert_eq(map.links, {})
	assert_eq(map.display_name, "")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/map/test_map_ascii_importer.gd -gexit`
Expected: FAIL（`display_name` 空、`get_neighbor` 回空、link 測試 `null` 等）

- [ ] **Step 3: 實作**

(a) 把 `parse` 開頭的累加變數（原本只有 `var theme_id := "default"`）擴成：

```gdscript
	var theme_id := "default"
	var display_name := ""
	var neighbors := {}
	var entries := {}
	var link_markers := {}   # String(char) -> { "map": String, "entry": String }
```

(b) 把 header 消化迴圈內「只處理 theme」那段，換成 match 派發：

```gdscript
	while not lines.is_empty() and _is_directive(lines[0]):
		var directive: String = lines[0]
		lines.remove_at(0)
		var colon := directive.find(":")
		var key := directive.substr(0, colon).strip_edges()
		var value := directive.substr(colon + 1).strip_edges()
		var parts := key.split(" ", false)
		var cmd: String = parts[0] if parts.size() > 0 else ""
		match cmd:
			"theme":
				if value != "":
					theme_id = value
			"name":
				display_name = value
			"north", "east", "south", "west":
				if value != "":
					neighbors[_word_to_dir(cmd)] = value
			"entry":
				if parts.size() >= 2:
					var e := _parse_entry_value(value)
					if not e.is_empty():
						entries[parts[1]] = e
			"link":
				if parts.size() >= 2:
					var l := _parse_link_value(value)
					if not l.is_empty():
						link_markers[parts[1]] = l
			_:
				pass  # 未知指令忽略
```

(c) 在 `var encounters := {}` 旁邊加 `var links := {}`。

(d) 網格內層迴圈把「未知字元 → null」那段，改成先試大寫標記：

```gdscript
			var t := _char_to_tile(ch)
			if t == -1:
				if _is_encounter_marker(ch):
					t = MapData.TileType.FLOOR
					encounters[Vector2i(x, y)] = ch
				elif link_markers.has(ch):
					t = MapData.TileType.FLOOR
					links[Vector2i(x, y)] = link_markers[ch]
				else:
					return null  # 未知字元
```

(e) 在 `var map := MapData.new()` 後、`return map` 前，補上：

```gdscript
	entries["start"] = { "pos": start_pos, "facing": GridDirection.Dir.NORTH }
	map.display_name = display_name
	map.neighbors = neighbors
	map.entries = entries
	map.links = links
```

(f) 把既有 `_is_directive` 換成（簡化、支援帶空白/大寫 key）：

```gdscript
# 指令行 = 含 ":" 的行。合法格子字元（# . @ D < > a-z A-Z）皆不含 ":"，故無歧義。
static func _is_directive(line: String) -> bool:
	return line.find(":") > 0
```

(g) 檔尾新增四個 helper：

```gdscript
static func _word_to_dir(word: String) -> int:
	match word:
		"north": return GridDirection.Dir.NORTH
		"east": return GridDirection.Dir.EAST
		"south": return GridDirection.Dir.SOUTH
		"west": return GridDirection.Dir.WEST
		_: return GridDirection.Dir.NORTH

static func _facing_word_to_dir(word: String) -> int:
	match word.to_upper():
		"N": return GridDirection.Dir.NORTH
		"E": return GridDirection.Dir.EAST
		"S": return GridDirection.Dir.SOUTH
		"W": return GridDirection.Dir.WEST
		_: return GridDirection.Dir.NORTH

# "4,9 S" -> {pos: Vector2i(4,9), facing: SOUTH}；facing 省略→NORTH；畸形→{}
static func _parse_entry_value(value: String) -> Dictionary:
	var toks := value.split(" ", false)
	if toks.is_empty():
		return {}
	var coords := toks[0].split(",", false)
	if coords.size() < 2:
		return {}
	if not (coords[0].is_valid_int() and coords[1].is_valid_int()):
		return {}
	var facing := GridDirection.Dir.NORTH
	if toks.size() >= 2:
		facing = _facing_word_to_dir(toks[1])
	return { "pos": Vector2i(int(coords[0]), int(coords[1])), "facing": facing }

# "town_oak.gate" -> {map:"town_oak", entry:"gate"}；"town_oak" -> entry "start"；空 → {}
static func _parse_link_value(value: String) -> Dictionary:
	if value == "":
		return {}
	var dot := value.find(".")
	if dot == -1:
		return { "map": value, "entry": "start" }
	return { "map": value.substr(0, dot), "entry": value.substr(dot + 1) }
```

- [ ] **Step 4: 跑測試確認通過**（含既有 importer 測試不回歸）

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/map/test_map_ascii_importer.gd -gexit`
Expected: PASS（新舊全綠；既有 `test_theme_header_sets_theme_id` / `test_unknown_directive_ignored` 仍過）

- [ ] **Step 5: Commit**

```bash
git add engine/map/map_ascii_importer.gd tests/engine/map/test_map_ascii_importer.gd && git commit -m "feat(map): parse name/neighbors/entry/link headers and uppercase link markers"
```

---

### Task 3: `MapTransitions` 純切換邏輯

**Files:**
- Create: `engine/map/map_transitions.gd`
- Test: `tests/engine/map/test_map_transitions.gd`

**Interfaces:**
- Consumes: `MapData`（`width`/`height`/`get_tile`/`has_neighbor`/`get_neighbor`/`has_link`/`get_link`）、`GridDirection`、`MapBuilder.is_walkable_type`。
- Produces:
  - `MapTransitions.edge_exit(map: MapData, pos: Vector2i, move_dir: int) -> Dictionary`：目標出界且該向有鄰圖 → `{ "neighbor_id": String, "edge_dir": int, "lateral": int }`，否則 `{}`。
  - `MapTransitions.arrival_cell(dest_map: MapData, edge_dir: int, lateral: int) -> Vector2i`：對邊同側格；lateral 出界或對邊實心 → `Vector2i(-1, -1)`。
  - `MapTransitions.resolve_link(map: MapData, pos: Vector2i) -> Dictionary`：該格有 link → `{map, entry}`，否則 `{}`。

- [ ] **Step 1: 寫失敗測試** `tests/engine/map/test_map_transitions.gd`

```gdscript
extends GutTest

func _floor_map(w: int, h: int) -> MapData:
	var map := MapData.new()
	map.width = w
	map.height = h
	var t := PackedInt32Array()
	t.resize(w * h)  # 全 0 = FLOOR
	map.tiles = t
	return map

func test_edge_exit_inside_bounds_returns_empty():
	var map := _floor_map(3, 3)
	map.neighbors = { GridDirection.Dir.EAST: "east" }
	assert_eq(MapTransitions.edge_exit(map, Vector2i(1, 1), GridDirection.Dir.EAST), {})

func test_edge_exit_out_of_bounds_with_neighbor():
	var map := _floor_map(3, 3)
	map.neighbors = { GridDirection.Dir.EAST: "east" }
	var r := MapTransitions.edge_exit(map, Vector2i(2, 1), GridDirection.Dir.EAST)
	assert_eq(r, { "neighbor_id": "east", "edge_dir": GridDirection.Dir.EAST, "lateral": 1 })

func test_edge_exit_out_of_bounds_without_neighbor():
	var map := _floor_map(3, 3)
	assert_eq(MapTransitions.edge_exit(map, Vector2i(2, 1), GridDirection.Dir.EAST), {})

func test_edge_exit_north_lateral_is_x():
	var map := _floor_map(3, 3)
	map.neighbors = { GridDirection.Dir.NORTH: "n" }
	var r := MapTransitions.edge_exit(map, Vector2i(2, 0), GridDirection.Dir.NORTH)
	assert_eq(r, { "neighbor_id": "n", "edge_dir": GridDirection.Dir.NORTH, "lateral": 2 })

func test_arrival_cell_opposite_edge():
	var dest := _floor_map(4, 4)
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.EAST, 2), Vector2i(0, 2))
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.NORTH, 1), Vector2i(1, 3))
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.WEST, 0), Vector2i(3, 0))
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.SOUTH, 3), Vector2i(3, 0))

func test_arrival_cell_blocked_when_solid():
	var dest := _floor_map(3, 3)
	dest.tiles[1 * 3 + 0] = MapData.TileType.WALL  # (0,1) 設牆
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.EAST, 1), Vector2i(-1, -1))

func test_arrival_cell_lateral_out_of_range():
	var dest := _floor_map(3, 3)
	assert_eq(MapTransitions.arrival_cell(dest, GridDirection.Dir.EAST, 9), Vector2i(-1, -1))

func test_resolve_link_hit_and_miss():
	var map := _floor_map(3, 3)
	map.links = { Vector2i(2, 1): {"map": "town", "entry": "gate"} }
	assert_eq(MapTransitions.resolve_link(map, Vector2i(2, 1)), {"map": "town", "entry": "gate"})
	assert_eq(MapTransitions.resolve_link(map, Vector2i(0, 0)), {})
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/map/test_map_transitions.gd -gexit`
Expected: FAIL（`Identifier "MapTransitions" not declared`）

- [ ] **Step 3: 實作** `engine/map/map_transitions.gd`

```gdscript
class_name MapTransitions
extends Object

# 自 move_dir 走出 map 邊緣（目標出界）且該向有鄰圖 → 邊緣切換事件。
static func edge_exit(map: MapData, pos: Vector2i, move_dir: int) -> Dictionary:
	var target := pos + GridDirection.to_vector(move_dir)
	if target.x >= 0 and target.x < map.width and target.y >= 0 and target.y < map.height:
		return {}  # 仍在界內 → 非邊緣事件
	if not map.has_neighbor(move_dir):
		return {}
	var lateral: int
	if move_dir == GridDirection.Dir.EAST or move_dir == GridDirection.Dir.WEST:
		lateral = pos.y  # 東西向移動 → 保留 y
	else:
		lateral = pos.x  # 南北向移動 → 保留 x
	return { "neighbor_id": map.get_neighbor(move_dir), "edge_dir": move_dir, "lateral": lateral }

# 自 edge_dir 離開來源 → 進 dest 的「對邊」、同側 lateral 格。
# lateral 出界或對邊格實心 → Vector2i(-1, -1)（擋住）。
static func arrival_cell(dest_map: MapData, edge_dir: int, lateral: int) -> Vector2i:
	var cell: Vector2i
	match edge_dir:
		GridDirection.Dir.EAST: cell = Vector2i(0, lateral)
		GridDirection.Dir.WEST: cell = Vector2i(dest_map.width - 1, lateral)
		GridDirection.Dir.SOUTH: cell = Vector2i(lateral, 0)
		GridDirection.Dir.NORTH: cell = Vector2i(lateral, dest_map.height - 1)
		_: return Vector2i(-1, -1)
	if cell.x < 0 or cell.x >= dest_map.width or cell.y < 0 or cell.y >= dest_map.height:
		return Vector2i(-1, -1)
	if not MapBuilder.is_walkable_type(dest_map.get_tile(cell)):
		return Vector2i(-1, -1)
	return cell

static func resolve_link(map: MapData, pos: Vector2i) -> Dictionary:
	if map.has_link(pos):
		return map.get_link(pos)
	return {}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/map/test_map_transitions.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add engine/map/map_transitions.gd tests/engine/map/test_map_transitions.gd && git commit -m "feat(map): add MapTransitions (edge_exit/arrival_cell/resolve_link)"
```

---

### Task 4: `GridMovement.direction_of`

**Files:**
- Modify: `engine/grid/grid_movement.gd`
- Test: `tests/engine/grid/test_grid_movement.gd`

**Interfaces:**
- Consumes: `GridMovement.Move`、`GridDirection`。
- Produces: `GridMovement.direction_of(facing: int, move: int) -> int`（回傳該 move 的世界方向）。`resolve` 改用它（行為不變）。

- [ ] **Step 1: 寫失敗測試**（附加到 `tests/engine/grid/test_grid_movement.gd` 檔尾）

```gdscript
func test_direction_of_all_moves_facing_north():
	assert_eq(GridMovement.direction_of(GridDirection.Dir.NORTH, GridMovement.Move.FORWARD), GridDirection.Dir.NORTH)
	assert_eq(GridMovement.direction_of(GridDirection.Dir.NORTH, GridMovement.Move.BACKWARD), GridDirection.Dir.SOUTH)
	assert_eq(GridMovement.direction_of(GridDirection.Dir.NORTH, GridMovement.Move.STRAFE_LEFT), GridDirection.Dir.WEST)
	assert_eq(GridMovement.direction_of(GridDirection.Dir.NORTH, GridMovement.Move.STRAFE_RIGHT), GridDirection.Dir.EAST)

func test_direction_of_facing_east_forward():
	assert_eq(GridMovement.direction_of(GridDirection.Dir.EAST, GridMovement.Move.FORWARD), GridDirection.Dir.EAST)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/grid/test_grid_movement.gd -gexit`
Expected: FAIL（`Invalid call ... 'direction_of'`）

- [ ] **Step 3: 實作**（改寫 `engine/grid/grid_movement.gd` 的 `resolve`，新增 `direction_of`）

```gdscript
static func direction_of(facing: int, move: int) -> int:
	match move:
		Move.FORWARD: return facing
		Move.BACKWARD: return GridDirection.opposite(facing)
		Move.STRAFE_LEFT: return GridDirection.turn_left(facing)
		Move.STRAFE_RIGHT: return GridDirection.turn_right(facing)
		_: return facing

static func resolve(grid: GridData, pos: Vector2i, facing: int, move: int) -> Vector2i:
	var target := pos + GridDirection.to_vector(direction_of(facing, move))
	if grid.is_walkable(target):
		return target
	return pos
```

- [ ] **Step 4: 跑測試確認通過**（含既有 `resolve` 測試不回歸）

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/grid/test_grid_movement.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add engine/grid/grid_movement.gd tests/engine/grid/test_grid_movement.gd && git commit -m "feat(grid): add GridMovement.direction_of and use it in resolve"
```

---

### Task 5: `MapManager.enter_map` + `SaveSystem.apply_to` 共用

**Files:**
- Modify: `autoload/map_manager.gd`
- Modify: `autoload/save_system.gd`
- Test: `tests/autoload/test_map_manager.gd`（既有 `tests/autoload/test_save_system_*.gd` 必須不回歸）

**Interfaces:**
- Consumes: `MapData.clear_encounter`、既有 `MapManager.load_by_id`。
- Produces: `MapManager.enter_map(map_id: String, cleared_positions: Array = []) -> MapData`（載入後逐格 `clear_encounter`，並設 `current_map`/`current_grid`）。`SaveSystem.apply_to` 改呼叫它。

- [ ] **Step 1: 寫失敗測試**（附加到 `tests/autoload/test_map_manager.gd` 檔尾）

```gdscript
func test_enter_map_clears_given_encounters():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.enter_map("level01", [Vector2i(2, 2)])
	assert_not_null(map)
	assert_eq(map.map_id, "level01")
	assert_false(map.has_encounter(Vector2i(2, 2)), "已清座標不應再有遭遇")
	assert_eq(mm.current_map, map)

func test_enter_map_without_cleared_keeps_encounters():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.enter_map("level01")
	assert_true(map.has_encounter(Vector2i(2, 2)))
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/autoload/test_map_manager.gd -gexit`
Expected: FAIL（`Invalid call ... 'enter_map'`）

- [ ] **Step 3: 實作**

(a) `autoload/map_manager.gd` 檔尾新增：

```gdscript
# 載入地圖並重套「已清遭遇」座標（切換/讀檔重入地圖共用，避免已清的怪復活）。
func enter_map(map_id: String, cleared_positions: Array = []) -> MapData:
	var map := load_by_id(map_id)
	for pos in cleared_positions:
		map.clear_encounter(pos)
	return map
```

(b) `autoload/save_system.gd` 的 `apply_to`，把結尾這兩段：

```gdscript
	mm.load_by_id(data.map_id)
	for pos in gs.cleared_for(data.map_id):
		mm.current_map.clear_encounter(pos)
```

換成單行：

```gdscript
	mm.enter_map(data.map_id, gs.cleared_for(data.map_id))
```

- [ ] **Step 4: 跑測試確認通過**（map_manager 新測試 + save 既有測試皆綠）

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/autoload/test_map_manager.gd -gexit`
Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/autoload/test_save_system_capture_apply.gd,res://tests/autoload/test_save_system_integration.gd -gexit`
Expected: 兩者皆 PASS

- [ ] **Step 5: Commit**

```bash
git add autoload/map_manager.gd autoload/save_system.gd tests/autoload/test_map_manager.gd && git commit -m "feat(map): add MapManager.enter_map; SaveSystem.apply_to reuses it"
```

---

### Task 6: `PlayerController` 出界發 `edge_exit_attempted`

**Files:**
- Modify: `presentation/world/player_controller.gd`
- Test: `tests/presentation/test_player_controller.gd`

**Interfaces:**
- Consumes: Task 4 `GridMovement.direction_of`；`GridData.in_bounds`/`is_walkable`；`GridDirection.to_vector`。
- Produces: `signal edge_exit_attempted(move_dir: int)`。`_attempt_move` 改為三分支：界內可走→補間移動（同現況）；界內實心→撞牆不動（同現況，不發訊號）；出界→發 `edge_exit_attempted(move_dir)` 並 return（不補間）。

- [ ] **Step 1: 寫失敗測試**（附加到 `tests/presentation/test_player_controller.gd` 檔尾）

```gdscript
func test_edge_move_emits_edge_exit_attempted():
	# 站最北排 (1,0) 面向 NORTH 前進 → 出界 → 發 edge_exit_attempted(NORTH)
	var pc := _make_pc(GridData.new(3, 3), Vector2i(1, 0), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)
	assert_signal_emitted_with_parameters(pc, "edge_exit_attempted", [GridDirection.Dir.NORTH])
	assert_signal_not_emitted(pc, "entered_cell")
	assert_eq(pc._pos, Vector2i(1, 0), "出界不移動")

func test_inbounds_wall_does_not_emit_edge_exit():
	var grid := GridData.new(3, 3)
	grid.set_solid(Vector2i(1, 0), true)  # 界內牆
	var pc := _make_pc(grid, Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)
	assert_signal_not_emitted(pc, "edge_exit_attempted")
	assert_signal_not_emitted(pc, "entered_cell")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_player_controller.gd -gexit`
Expected: FAIL（訊號 `edge_exit_attempted` 不存在）

- [ ] **Step 3: 實作**

(a) 在既有兩個 `signal` 下方新增：

```gdscript
signal edge_exit_attempted(move_dir: int)
```

(b) 把 `_attempt_move` 整個換成：

```gdscript
func _attempt_move(move: int) -> void:
	var move_dir := GridMovement.direction_of(_facing, move)
	var target := _pos + GridDirection.to_vector(move_dir)
	if not _grid.in_bounds(target):
		edge_exit_attempted.emit(move_dir)  # 出界 → 交給 main 判斷是否切換
		return
	if not _grid.is_walkable(target):
		return  # 界內撞牆，不動
	_pos = target
	entered_cell.emit(_pos)
	_is_busy = true
	var tween := create_tween()
	tween.tween_property(self, "position", GridGeometry.cell_to_world(_pos), MOVE_TIME)
	tween.finished.connect(func(): _is_busy = false)
```

- [ ] **Step 4: 跑測試確認通過**（含既有移動/撞牆測試不回歸）

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/presentation/test_player_controller.gd -gexit`
Expected: PASS（`test_move_emits_entered_cell_with_new_pos` / `test_blocked_move_does_not_emit_entered_cell` 仍綠）

- [ ] **Step 5: Commit**

```bash
git add presentation/world/player_controller.gd tests/presentation/test_player_controller.gd && git commit -m "feat(world): PlayerController emits edge_exit_attempted on out-of-bounds move"
```

---

### Task 7: 示範世界（2×2 野外 + 城鎮）+ 連通性測試

**Files:**
- Create: `content/maps/wild_nw.txt`、`content/maps/wild_ne.txt`、`content/maps/wild_sw.txt`、`content/maps/wild_se.txt`、`content/maps/town_oak.txt`
- Test: `tests/content/test_world_maps.gd`

**Interfaces:**
- Consumes: Task 2 importer、`MapManager.load_by_id`。
- Produces: 一個連通示範世界。野外 `wild_nw/ne/sw/se` 排成 2×2（皆 5×5、全地板、四向以鄰圖接壤）；`wild_nw` 的 `T`(3,3) 連到 `town_oak.gate`，並有命名入口 `from_town`(2,3)；`town_oak` 的 `W`(2,3) 連回 `wild_nw.from_town`，入口 `gate`(2,1) 面向 S。

> 注意：野外地圖**邊緣為地板**（非牆環），玩家才走得到邊緣觸發接壤；每張圖恰一個 `@`（importer 要求唯一起點，且 `@` 會生成 `start` 入口）。

- [ ] **Step 1: 寫示範地圖檔**

`content/maps/wild_nw.txt`：

```
theme: default
name: 西北野
east: wild_ne
south: wild_sw
entry from_town: 2,3 N
link T: town_oak.gate
.....
.....
..@..
...T.
.....
```

`content/maps/wild_ne.txt`：

```
theme: default
name: 東北野
west: wild_nw
south: wild_se
..@..
.....
.....
.....
.....
```

`content/maps/wild_sw.txt`：

```
theme: default
name: 西南野
north: wild_nw
east: wild_se
.....
.....
..@..
.....
.....
```

`content/maps/wild_se.txt`：

```
theme: default
name: 東南野
north: wild_ne
west: wild_sw
.....
.....
..@..
.....
.....
```

`content/maps/town_oak.txt`：

```
theme: default
name: 橡鎮
entry gate: 2,1 S
link W: wild_nw.from_town
#####
#...#
#.@.#
#.W.#
#####
```

- [ ] **Step 2: 寫失敗測試** `tests/content/test_world_maps.gd`

```gdscript
extends GutTest

const MapManagerScript := preload("res://autoload/map_manager.gd")

func _load(id: String) -> MapData:
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	return mm.load_by_id(id)

func test_wilderness_2x2_neighbors_symmetric():
	var nw := _load("wild_nw")
	var ne := _load("wild_ne")
	var sw := _load("wild_sw")
	var se := _load("wild_se")
	assert_eq(nw.get_neighbor(GridDirection.Dir.EAST), "wild_ne")
	assert_eq(ne.get_neighbor(GridDirection.Dir.WEST), "wild_nw")
	assert_eq(nw.get_neighbor(GridDirection.Dir.SOUTH), "wild_sw")
	assert_eq(sw.get_neighbor(GridDirection.Dir.NORTH), "wild_nw")
	assert_eq(ne.get_neighbor(GridDirection.Dir.SOUTH), "wild_se")
	assert_eq(se.get_neighbor(GridDirection.Dir.NORTH), "wild_ne")
	assert_eq(sw.get_neighbor(GridDirection.Dir.EAST), "wild_se")
	assert_eq(se.get_neighbor(GridDirection.Dir.WEST), "wild_sw")

func test_wilderness_maps_share_dimensions():
	for id in ["wild_nw", "wild_ne", "wild_sw", "wild_se"]:
		var m := _load(id)
		assert_eq(m.width, 5, "%s width" % id)
		assert_eq(m.height, 5, "%s height" % id)

func test_town_link_roundtrip():
	var nw := _load("wild_nw")
	assert_eq(nw.get_link(Vector2i(3, 3)), {"map": "town_oak", "entry": "gate"})
	assert_true(nw.has_entry("from_town"))
	assert_eq(nw.get_entry("from_town"), {"pos": Vector2i(2, 3), "facing": GridDirection.Dir.NORTH})
	var town := _load("town_oak")
	assert_eq(town.get_entry("gate"), {"pos": Vector2i(2, 1), "facing": GridDirection.Dir.SOUTH})
	assert_eq(town.get_link(Vector2i(2, 3)), {"map": "wild_nw", "entry": "from_town"})
```

- [ ] **Step 3: 跑測試確認通過**（地圖檔已寫，測試應直接綠；若紅代表地圖檔有誤，修檔）

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/content/test_world_maps.gd -gexit`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add content/maps/wild_nw.txt content/maps/wild_ne.txt content/maps/wild_sw.txt content/maps/wild_se.txt content/maps/town_oak.txt tests/content/test_world_maps.gd && git commit -m "content: add 2x2 wilderness + town_oak demo world for M7"
```

---

### Task 8: `main.gd` 串接轉場（淡出黑幕 + 邊緣/入口切換 + 起始圖 + town_portal）

**Files:**
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes: Task 3 `MapTransitions`、Task 5 `MapManager.enter_map`、Task 6 `PlayerController.edge_exit_attempted`、`GameState`、`MapData.display_name/get_entry/start_pos`。
- Produces: 無公開 API（呈現整合根）。新增 `_enter_via_link`、`_on_edge_exit_attempted`、`_setup_fade`、`_fade`；改寫 `_ready`、`_on_entered_cell`、`_cast_recall`。

> 本檔為呈現整合根，照本專案慣例**不寫單元測試**；以全套測試不回歸 + `./run.sh` 手動目視驗證。
> 時序註記：`MOVE_TIME=0.18 < 淡出 0.2s`，故觸發入口連結時舊的移動補間會在黑幕下自然結束，重建後 `setup()` 直接定位、不打架。邊緣切換不啟動補間（`_attempt_move` 出界即 return），故**邊緣切換即時、無黑幕**（野外無縫）；入口連結才走黑幕 + 到達訊息。

- [ ] **Step 1: 改 `_ready` 起始圖來源 + 掛接 + 黑幕**

把開頭常數區：

```gdscript
const MAP_PATH := "res://content/maps/level01.txt"
```

換成：

```gdscript
const START_MAP_ID := "wild_nw"   # 起始地圖（M7 示範世界入口）
const HOME_MAP_ID := "town_oak"   # town_portal（recall）目的地
const HOME_ENTRY := "gate"
```

把 `_ready()` 開頭：

```gdscript
	var map := MapManager.load_text_file(MAP_PATH)
	_world_builder.build(map)
	_setup_environment()
```

換成：

```gdscript
	var map := MapManager.enter_map(START_MAP_ID, GameState.cleared_for(START_MAP_ID))
	_world_builder.build(map)
	_setup_environment()
	_setup_fade()
```

把 `_ready()` 內連接玩家訊號那段（`_player.entered_cell.connect(...)` 與 `_player.facing_changed.connect(...)` 附近）加一行：

```gdscript
	_player.edge_exit_attempted.connect(_on_edge_exit_attempted)
```

把 `_ready()` 結尾的：

```gdscript
	_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)

	GameState.current_map_id = map.map_id
	GameState.player_pos = map.start_pos
	GameState.player_facing = map.start_facing
```

換成（`enter_map` 不設 `map_id`，這裡用常數）：

```gdscript
	_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)

	GameState.current_map_id = START_MAP_ID
	GameState.player_pos = map.start_pos
	GameState.player_facing = map.start_facing
```

- [ ] **Step 2: 改 `_on_entered_cell` 先做 link 檢查**

把整個 `_on_entered_cell` 換成：

```gdscript
func _on_entered_cell(pos: Vector2i) -> void:
	GameState.player_pos = pos
	var link := MapTransitions.resolve_link(MapManager.current_map, pos)
	if not link.is_empty():
		_enter_via_link(link["map"], link["entry"])
		return
	if MapManager.current_map.has_encounter(pos):
		_start_combat(pos)
		return
	var text := TileMessages.for_tile(MapManager.current_map.get_tile(pos))
	if text != "":
		GameState.message_log.push(text)
```

- [ ] **Step 3: 新增切換 / 黑幕 / 邊緣處理函式**（加在 `_on_facing_changed` 附近）

```gdscript
var _fade_rect: ColorRect

func _setup_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)
	add_child(layer)

func _fade(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", target_alpha, 0.2)
	await tween.finished

# 入口連結切換：淡出 → 載入目的地 + 命名入口 → 重建定位 → 訊息 → 淡入。
func _enter_via_link(map_id: String, entry_name: String) -> void:
	_player.set_enabled(false)
	await _fade(1.0)
	var dest := MapManager.enter_map(map_id, GameState.cleared_for(map_id))
	var e := dest.get_entry(entry_name)
	var pos: Vector2i = e.get("pos", dest.start_pos)
	var facing: int = e.get("facing", GridDirection.Dir.NORTH)
	_world_builder.build(MapManager.current_map)
	_player.setup(MapManager.current_grid, pos, facing)
	GameState.current_map_id = map_id
	GameState.player_pos = pos
	GameState.player_facing = facing
	var nm: String = dest.display_name if dest.display_name != "" else map_id
	GameState.message_log.push("你來到%s。" % nm)
	_hud.refresh()
	await _fade(0.0)
	_player.set_enabled(true)

# 邊緣接壤：即時、無黑幕、保持面向（野外無縫）。
func _on_edge_exit_attempted(move_dir: int) -> void:
	var ex := MapTransitions.edge_exit(MapManager.current_map, GameState.player_pos, move_dir)
	if ex.is_empty():
		return
	var neighbor_id: String = ex["neighbor_id"]
	var dest := MapManager.enter_map(neighbor_id, GameState.cleared_for(neighbor_id))
	var cell := MapTransitions.arrival_cell(dest, ex["edge_dir"], ex["lateral"])
	if cell == Vector2i(-1, -1):
		# 對邊實心 → 不能過去；還原當前地圖（enter_map 已切走 current）
		MapManager.enter_map(GameState.current_map_id, GameState.cleared_for(GameState.current_map_id))
		return
	_world_builder.build(MapManager.current_map)
	_player.setup(MapManager.current_grid, cell, GameState.player_facing)
	GameState.current_map_id = neighbor_id
	GameState.player_pos = cell
	_hud.refresh()
```

- [ ] **Step 4: 接上 `town_portal`（recall）**

把既有 stub：

```gdscript
func _cast_recall(spell: SpellDef) -> void:
	# STUB（M5c 殼）：城市傳送目的地待多地圖基建後實作。
	GameState.message_log.push("%s 尚未接上世界效果。" % spell.display_name)
```

換成：

```gdscript
func _cast_recall(spell: SpellDef) -> void:
	GameState.message_log.push("%s 發動……" % spell.display_name)
	_enter_via_link(HOME_MAP_ID, HOME_ENTRY)
```

- [ ] **Step 5: 跑全套測試確認不回歸**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: 全套 PASS（M1–M6 既有測試 + 本計畫新測試；先前基準 247 + 本計畫新增）

- [ ] **Step 6: 手動目視驗證**（`./run.sh`）

依序確認：
1. 啟動進入 `wild_nw`（西北野，全地板）。
2. 走到東緣前進 → 無縫接到 `wild_ne`（保持面向、同側位置，無黑幕）；四向繞 2×2 接壤一圈回到起點。
3. 走到 `wild_nw` 的 `T`(3,3) → 黑幕淡出入，到達「橡鎮」並出現「你來到橡鎮。」訊息。
4. 城鎮內走到 `W`(2,3) → 切回 `wild_nw`，落在 `from_town`(2,3)（不在 `T` 上、不反覆彈跳）。
5. 開法術選單施放 `town_portal`（M）→ 傳送到橡鎮。
6. 存檔（Tab）→ 重啟 `./run.sh` → 讀檔回到存檔當下的地圖與座標。

- [ ] **Step 7: Commit**

```bash
git add presentation/world/main.gd && git commit -m "feat(world): wire map transitions (edge seam + entrance links), fade, town_portal"
```

---

## Self-Review

**1. Spec coverage**（對照 spec 各節）：
- 邊緣接壤 → Task 3 `edge_exit`/`arrival_cell` + Task 6 訊號 + Task 8 `_on_edge_exit_attempted`。✓
- 入口連結 → Task 2 `link`/標記解析 + Task 3 `resolve_link` + Task 8 `_enter_via_link`。✓
- header 自我描述（name/neighbors/entry/link）→ Task 2。✓
- `MapData` 四欄位 → Task 1。✓
- 單一進入路徑 + 重入重套已清遭遇 → Task 5 `enter_map`（存讀檔共用）。✓
- 命名入口（`@`→`start`）→ Task 2。✓
- 存檔 schema 不變 → 無 SaveSerializer 改動；`enter_map` 僅重構。✓
- 起始圖來源、黑幕、town_portal → Task 8。✓
- 示範世界（2×2 + 城鎮）→ Task 7。✓
- 舊地圖不回歸（level01）→ Task 2 `test_old_map_has_empty_world_fields` + Task 5 沿用 level01 + 全套測試。✓

**2. Placeholder scan**：無 TBD/TODO/「類似 Task N」；每個程式步驟皆附完整程式碼。✓

**3. Type consistency**：`edge_exit` 回 `{neighbor_id, edge_dir, lateral}`，Task 8 以這三鍵取用；`arrival_cell(dest, edge_dir, lateral)` 簽章一致；`resolve_link`/`get_link` 皆回 `{map, entry}`，Task 8 以 `link["map"]`/`link["entry"]` 取用；`get_entry` 回 `{pos, facing}`，Task 8 以 `e.get("pos")`/`e.get("facing")` 取用；`enter_map(map_id, cleared_positions)` 在 Task 5/8 與 SaveSystem 簽章一致。✓

> 邊界檢查備忘（已反映在程式）：`arrival_cell` 對 `SOUTH` 進入回 `Vector2i(lateral, 0)`、`NORTH` 回 `Vector2i(lateral, height-1)`、`EAST` 回 `Vector2i(0, lateral)`、`WEST` 回 `Vector2i(width-1, lateral)`；測試 `test_arrival_cell_opposite_edge` 已涵蓋四向。
