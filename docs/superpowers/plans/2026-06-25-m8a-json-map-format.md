# M8a 地圖格式 JSON 化（物件層前置重構）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把地圖來源格式從「header 指令 + 純 ASCII 網格的 `.txt`」換成「JSON 容器（`grid` 為 ASCII 列字串陣列 ＋ 結構化 `entities`/`entries`/`neighbors`）」，`MapImporter` 改吃 JSON 並產出語義完全相同的 `MapData`。

**Architecture:** 新增純函式 `MapImporter.parse(json_text) -> MapData`（取代 `MapAsciiImporter`）。`grid` 沿用既有 `_char_to_tile` 字元集；怪物與 portal 改由 `entities` 陣列宣告，importer 把它們分配進既有的 `MapData.encounters` / `links`。`MapData` 形狀、runtime、存檔 schema（v3）皆不變——本期是純 I/O 格式遷移，下游全部不動。

**Tech Stack:** Godot 4.7、GDScript、GUT 測試框架（`res://addons/gut/gut_cmdln.gd`）。JSON 用 Godot 內建 `JSON`（零依賴）。

## Global Constraints

- **零外部依賴**：JSON 解析只用 Godot 內建 `JSON` 類別；不得引入第三方 parser。
- **`MapData` 形狀不變**：不新增/刪除任何 `MapData` 欄位；`entities` 僅為輸入表示，由 importer 分配進既有 `encounters` / `links` / `entries` / `neighbors`。
- **存檔 schema 不變**：`SaveSerializer.VERSION` 維持 3，不碰任何 save 程式碼。
- **嚴格驗證**：任何違規 → `parse` 回 `null`（不做 log 副作用），延續既有 importer 契約。
- **合法格子字元僅 `# . @ D < >`**：字母（`a-z`/`A-Z`）在 `grid` 中一律視為未知字元 → `null`。怪物/portal 改走 `entities`。
- **本期 `entities` 僅 `monster` / `portal` 兩型**；未知 `type` → `null`（`chest` 留待步驟二）。
- **測試指令**（全套件）：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`。
- **測試指令**（單檔聚焦）：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<test_file.gd> -gexit`。**注意：用 `-gselect=<檔名>`（非 `-gtest=`，後者在本專案 GUT 會跑全套件而非聚焦）。**
- **新增 `class_name` 後須重匯入**：建立 `MapImporter`（新全域類別）後，GUT 可能無法解析該 class；先跑一次 `godot --headless --path . --import`，再跑測試。
- **繁體中文**：對使用者的說明用繁中；程式碼/commit 訊息維持既有慣例。

---

## File Structure

**新增**
- `engine/map/map_importer.gd` — `class_name MapImporter`，`parse(json_text) -> MapData`。唯一公開入口；內部 helper 解析 grid / neighbors / entries / entities，全純函式。
- `tests/engine/map/test_map_importer.gd` — `MapImporter` 的 GUT 測試（取代舊 importer 測試）。
- `content/maps/{level01,town_oak,wild_nw,wild_ne,wild_sw,wild_se}.json` — 6 張地圖轉檔。

**修改**
- `autoload/map_manager.gd` — `MapAsciiImporter` → `MapImporter`；地圖路徑 `.txt` → `.json`。
- `presentation/world/world_builder_preview.gd` — 讀 `level01.json`、用 `MapImporter`。
- `tests/autoload/test_map_manager.gd` — `load_text` 輸入由 ASCII 改 JSON。
- `tests/engine/map/test_map_builder.gd` — `_map` helper 改用 `MapImporter`（ASCII 包成 JSON grid）。
- `tests/presentation/test_world_builder.gd` — 同上 `_map` helper。

**刪除**
- `engine/map/map_ascii_importer.gd`（+ `.uid`）
- `tests/engine/map/test_map_ascii_importer.gd`（+ `.uid`）
- `content/maps/{level01,town_oak,wild_nw,wild_ne,wild_sw,wild_se}.txt`（6 檔）

---

## Task 1: MapImporter（JSON → MapData，純函式）

**Files:**
- Create: `engine/map/map_importer.gd`
- Test: `tests/engine/map/test_map_importer.gd`

**Interfaces:**
- Consumes: `MapData`（既有 Resource，欄位不變）、`GridDirection.Dir`、`MapData.TileType`。
- Produces: `MapImporter.parse(json_text: String) -> MapData`（違規回 `null`）。後續 Task 2/3 透過此函式載入地圖。

- [ ] **Step 1: 寫失敗測試** — 建立 `tests/engine/map/test_map_importer.gd`

```gdscript
extends GutTest

# 傳一個 Dictionary，stringify 後交給 parse，讓測試精簡可讀。
func _p(d) -> MapData:
	return MapImporter.parse(JSON.stringify(d))

func test_parse_simple_grid():
	var m := _p({"grid": ["###", "#@.", "###"]})
	assert_not_null(m)
	assert_eq(m.width, 3)
	assert_eq(m.height, 3)
	assert_eq(m.start_pos, Vector2i(1, 1))
	assert_eq(m.start_facing, GridDirection.Dir.NORTH)
	assert_eq(m.get_tile(Vector2i(0, 0)), MapData.TileType.WALL)
	assert_eq(m.get_tile(Vector2i(1, 1)), MapData.TileType.FLOOR)
	assert_eq(m.get_tile(Vector2i(2, 1)), MapData.TileType.FLOOR)

func test_all_tile_types():
	var m := _p({"grid": ["@D<>"]})
	assert_not_null(m)
	assert_eq(m.get_tile(Vector2i(0, 0)), MapData.TileType.FLOOR)
	assert_eq(m.get_tile(Vector2i(1, 0)), MapData.TileType.DOOR)
	assert_eq(m.get_tile(Vector2i(2, 0)), MapData.TileType.STAIRS_UP)
	assert_eq(m.get_tile(Vector2i(3, 0)), MapData.TileType.STAIRS_DOWN)

func test_invalid_json_returns_null():
	assert_null(MapImporter.parse("{not json"))

func test_non_object_root_returns_null():
	assert_null(MapImporter.parse("[1, 2, 3]"))

func test_missing_grid_returns_null():
	assert_null(_p({"theme": "x"}))

func test_empty_grid_returns_null():
	assert_null(_p({"grid": []}))

func test_non_rectangular_returns_null():
	assert_null(_p({"grid": ["###", "#@", "###"]}))

func test_letters_in_grid_are_unknown_chars():
	# 字母不再是合法格子字元（怪物/連結改走 entities）
	assert_null(_p({"grid": ["@g"]}))
	assert_null(_p({"grid": ["@X"]}))

func test_missing_start_returns_null():
	assert_null(_p({"grid": ["###", "#.#", "###"]}))

func test_multiple_start_returns_null():
	assert_null(_p({"grid": ["@@"]}))

func test_theme_field_sets_theme_id():
	assert_eq(_p({"grid": ["@"], "theme": "castle"}).theme_id, "castle")

func test_missing_theme_defaults():
	assert_eq(_p({"grid": ["@"]}).theme_id, "default")

func test_empty_theme_defaults():
	assert_eq(_p({"grid": ["@"], "theme": ""}).theme_id, "default")

func test_name_field_sets_display_name():
	assert_eq(_p({"grid": ["@"], "name": "橡鎮"}).display_name, "橡鎮")

func test_neighbors_parsed():
	var m := _p({"grid": ["@"], "neighbors": {"north": "a", "east": "b", "south": "c", "west": "d"}})
	assert_eq(m.get_neighbor(GridDirection.Dir.NORTH), "a")
	assert_eq(m.get_neighbor(GridDirection.Dir.EAST), "b")
	assert_eq(m.get_neighbor(GridDirection.Dir.SOUTH), "c")
	assert_eq(m.get_neighbor(GridDirection.Dir.WEST), "d")

func test_entries_with_and_without_facing():
	var m := _p({"grid": ["#@#"], "entries": {"gate": {"pos": [1, 0], "facing": "S"}, "spot": {"pos": [0, 0]}}})
	assert_eq(m.get_entry("gate"), {"pos": Vector2i(1, 0), "facing": GridDirection.Dir.SOUTH})
	assert_eq(m.get_entry("spot"), {"pos": Vector2i(0, 0), "facing": GridDirection.Dir.NORTH})

func test_at_creates_start_entry():
	assert_eq(_p({"grid": ["#@#"]}).get_entry("start"), {"pos": Vector2i(1, 0), "facing": GridDirection.Dir.NORTH})

func test_monster_entity_becomes_encounter():
	var m := _p({"grid": ["#@.", "..."], "entities": [{"type": "monster", "pos": [2, 0], "encounter": "g"}]})
	assert_not_null(m)
	assert_eq(m.get_tile(Vector2i(2, 0)), MapData.TileType.FLOOR)
	assert_true(m.has_encounter(Vector2i(2, 0)))
	assert_eq(m.get_encounter(Vector2i(2, 0)), "g")

func test_multiple_monsters():
	var m := _p({"grid": ["@..", "..."], "entities": [
		{"type": "monster", "pos": [1, 0], "encounter": "g"},
		{"type": "monster", "pos": [2, 1], "encounter": "o"}]})
	assert_eq(m.get_encounter(Vector2i(1, 0)), "g")
	assert_eq(m.get_encounter(Vector2i(2, 1)), "o")

func test_portal_entity_with_entry():
	var m := _p({"grid": ["@."], "entities": [{"type": "portal", "pos": [1, 0], "to": "town_oak", "entry": "gate"}]})
	assert_true(m.has_link(Vector2i(1, 0)))
	assert_eq(m.get_link(Vector2i(1, 0)), {"map": "town_oak", "entry": "gate"})

func test_portal_without_entry_defaults_start():
	var m := _p({"grid": ["@."], "entities": [{"type": "portal", "pos": [1, 0], "to": "town_oak"}]})
	assert_eq(m.get_link(Vector2i(1, 0)), {"map": "town_oak", "entry": "start"})

func test_unknown_entity_type_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [{"type": "chest", "pos": [1, 0]}]}))

func test_entity_missing_pos_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [{"type": "monster", "encounter": "g"}]}))

func test_entity_missing_required_field_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [{"type": "monster", "pos": [1, 0]}]}))
	assert_null(_p({"grid": ["@."], "entities": [{"type": "portal", "pos": [1, 0]}]}))

func test_entity_pos_out_of_bounds_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [{"type": "monster", "pos": [5, 5], "encounter": "g"}]}))

func test_pos_accepts_json_float_numbers():
	# JSON 數字可能解析成 float；座標需正確轉 int
	var m := MapImporter.parse('{"grid":["@."],"entities":[{"type":"monster","pos":[1.0,0.0],"encounter":"g"}]}')
	assert_not_null(m)
	assert_true(m.has_encounter(Vector2i(1, 0)))

func test_minimal_map_has_empty_world_fields():
	var m := _p({"grid": ["@"]})
	assert_eq(m.neighbors, {})
	assert_eq(m.links, {})
	assert_eq(m.encounters, {})
	assert_eq(m.display_name, "")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_map_importer.gd -gexit`
Expected: FAIL／報錯 —「Identifier "MapImporter" not declared」（檔案尚未建立）。

- [ ] **Step 3: 寫最小實作** — 建立 `engine/map/map_importer.gd`

```gdscript
class_name MapImporter
extends Object

# JSON 地圖 → MapData；任何違規 → null（不做 log 副作用）。
# grid 為 ASCII 列字串陣列（字元集 # . @ D < >）；怪物/portal 走 entities，不再用格子字元。
static func parse(json_text: String) -> MapData:
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return null
	var root = json.data
	if typeof(root) != TYPE_DICTIONARY:
		return null
	if not root.has("grid"):
		return null

	var grid := _parse_grid(root["grid"])
	if grid.is_empty():
		return null

	var entities = _parse_entities(root.get("entities", []), grid["width"], grid["height"])
	if entities == null:
		return null

	var map := MapData.new()
	map.width = grid["width"]
	map.height = grid["height"]
	map.tiles = grid["tiles"]
	map.start_pos = grid["start_pos"]
	map.start_facing = GridDirection.Dir.NORTH

	var theme := String(root.get("theme", ""))
	map.theme_id = theme if theme != "" else "default"
	map.display_name = String(root.get("name", ""))
	map.neighbors = _parse_neighbors(root.get("neighbors", {}))

	var entries := _parse_entries(root.get("entries", {}))
	entries["start"] = {"pos": map.start_pos, "facing": GridDirection.Dir.NORTH}
	map.entries = entries

	map.encounters = entities["encounters"]
	map.links = entities["links"]
	return map

# --- internal ---

# rows -> { width, height, tiles, start_pos }；任何違規 → {}（空 = 失敗）。
static func _parse_grid(rows) -> Dictionary:
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		return {}
	if typeof(rows[0]) != TYPE_STRING:
		return {}
	var height := rows.size()
	var width: int = (rows[0] as String).length()
	if width == 0:
		return {}
	var tiles := PackedInt32Array()
	tiles.resize(width * height)
	var start_pos := Vector2i(-1, -1)
	for y in height:
		if typeof(rows[y]) != TYPE_STRING:
			return {}
		var line: String = rows[y]
		if line.length() != width:
			return {}
		for x in width:
			var t := _char_to_tile(line[x])
			if t == -1:
				return {}
			if line[x] == "@":
				if start_pos != Vector2i(-1, -1):
					return {}
				start_pos = Vector2i(x, y)
			tiles[y * width + x] = t
	if start_pos == Vector2i(-1, -1):
		return {}
	return {"width": width, "height": height, "tiles": tiles, "start_pos": start_pos}

# arr -> { encounters, links }；違規 → null。空陣列為合法（回空 dicts）。
static func _parse_entities(arr, width: int, height: int):
	if typeof(arr) != TYPE_ARRAY:
		return null
	var encounters := {}
	var links := {}
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
			_:
				return null
	return {"encounters": encounters, "links": links}

# [x, y] -> Vector2i；違規 → null。JSON 數字可能是 float，需 int() 轉。
static func _parse_pos(v):
	if typeof(v) != TYPE_ARRAY or v.size() < 2:
		return null
	if not (_is_num(v[0]) and _is_num(v[1])):
		return null
	return Vector2i(int(v[0]), int(v[1]))

static func _is_num(x) -> bool:
	return typeof(x) == TYPE_INT or typeof(x) == TYPE_FLOAT

static func _parse_neighbors(d) -> Dictionary:
	var out := {}
	if typeof(d) != TYPE_DICTIONARY:
		return out
	for key in ["north", "east", "south", "west"]:
		var v = d.get(key, "")
		if typeof(v) == TYPE_STRING and v != "":
			out[_word_to_dir(key)] = v
	return out

# { name: { pos:[x,y], facing?:"N/E/S/W" } } -> entries dict；畸形項目跳過（沿用既有 entry 容忍）。
static func _parse_entries(d) -> Dictionary:
	var out := {}
	if typeof(d) != TYPE_DICTIONARY:
		return out
	for name in d:
		var spec = d[name]
		if typeof(spec) != TYPE_DICTIONARY or not spec.has("pos"):
			continue
		var pos = _parse_pos(spec["pos"])
		if pos == null:
			continue
		var facing := GridDirection.Dir.NORTH
		if spec.has("facing"):
			facing = _facing_word_to_dir(String(spec["facing"]))
		out[String(name)] = {"pos": pos, "facing": facing}
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
```

- [ ] **Step 4: 跑測試確認通過**

先重匯入（新 `class_name` 需要）：`godot --headless --path . --import`
再跑：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_map_importer.gd -gexit`
Expected: PASS（全部 test_* 綠燈、0 fail）。

- [ ] **Step 5: Commit**

```bash
git add engine/map/map_importer.gd tests/engine/map/test_map_importer.gd && git commit -m "feat(map): add MapImporter (JSON grid + entities → MapData)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 地圖轉檔 + 接線（MapManager / preview / map_manager 測試）

**Files:**
- Create: `content/maps/level01.json`, `town_oak.json`, `wild_nw.json`, `wild_ne.json`, `wild_sw.json`, `wild_se.json`
- Delete: 上述 6 個對應的 `.txt`
- Modify: `autoload/map_manager.gd`, `presentation/world/world_builder_preview.gd`, `tests/autoload/test_map_manager.gd`

**Interfaces:**
- Consumes: `MapImporter.parse(json_text)`（Task 1）。
- Produces: `MapManager.load_by_id(id)` 從 `res://content/maps/<id>.json` 載入；`current_map` / `current_grid` 行為不變。

- [ ] **Step 1: 建立 6 張 JSON 地圖**（與舊 `.txt` 產出的 MapData 逐欄相同）

`content/maps/level01.json`：
```json
{
  "theme": "bricks",
  "grid": [
    "#######",
    "#@.D.<#",
    "#..#..#",
    "#..#..#",
    "#....##",
    "#.#..>#",
    "#######"
  ],
  "entities": [
    { "type": "monster", "pos": [2, 2], "encounter": "g" },
    { "type": "monster", "pos": [4, 4], "encounter": "o" }
  ]
}
```

`content/maps/town_oak.json`：
```json
{
  "name": "橡鎮",
  "theme": "default",
  "grid": ["#####", "#...#", "#.@.#", "#...#", "#####"],
  "entities": [
    { "type": "portal", "pos": [2, 3], "to": "wild_nw", "entry": "from_town" }
  ],
  "entries": { "gate": { "pos": [2, 1], "facing": "S" } }
}
```

`content/maps/wild_nw.json`：
```json
{
  "name": "西北野",
  "theme": "default",
  "grid": [".....", ".....", "..@..", ".....", "....."],
  "entities": [
    { "type": "portal", "pos": [3, 3], "to": "town_oak", "entry": "gate" }
  ],
  "entries": { "from_town": { "pos": [2, 3], "facing": "N" } },
  "neighbors": { "east": "wild_ne", "south": "wild_sw" }
}
```

`content/maps/wild_ne.json`：
```json
{
  "name": "東北野",
  "theme": "default",
  "grid": ["..@..", ".....", ".....", ".....", "....."],
  "neighbors": { "west": "wild_nw", "south": "wild_se" }
}
```

`content/maps/wild_sw.json`：
```json
{
  "name": "西南野",
  "theme": "default",
  "grid": [".....", ".....", "..@..", ".....", "....."],
  "neighbors": { "north": "wild_nw", "east": "wild_se" }
}
```

`content/maps/wild_se.json`：
```json
{
  "name": "東南野",
  "theme": "default",
  "grid": [".....", ".....", "..@..", ".....", "....."],
  "neighbors": { "north": "wild_ne", "west": "wild_sw" }
}
```

- [ ] **Step 2: 刪除舊 `.txt` 地圖**

```bash
rm content/maps/level01.txt content/maps/town_oak.txt content/maps/wild_nw.txt content/maps/wild_ne.txt content/maps/wild_sw.txt content/maps/wild_se.txt
```

- [ ] **Step 3: 改 `autoload/map_manager.gd`** — importer 與副檔名

`autoload/map_manager.gd:10-11`（`load_text`）改 importer 呼叫：
```gdscript
func load_text(text: String) -> MapData:
	var map := MapImporter.parse(text)
```
`autoload/map_manager.gd:16-24`（`load_text_file` 註解 + `load_by_id` 路徑）：
```gdscript
func load_text_file(path: String) -> MapData:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "MapManager.load_text_file: cannot read %s" % path)
	var map := load_text(text)
	map.map_id = path.get_file().get_basename()  # "level01.json" → "level01"
	return map

func load_by_id(id: String) -> MapData:
	return load_text_file("%s/%s.json" % [MAPS_DIR, id])
```

- [ ] **Step 4: 改 `presentation/world/world_builder_preview.gd`**

整檔內容改為：
```gdscript
extends Node3D

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://content/maps/level01.json")
	($WorldBuilder as WorldBuilder).build(MapImporter.parse(text))
```

- [ ] **Step 5: 改 `tests/autoload/test_map_manager.gd`** — `load_text` 輸入改 JSON

`tests/autoload/test_map_manager.gd:8`：
```gdscript
	var map := mm.load_text(JSON.stringify({"grid": ["###", "#@#", "###"]}))
```
（同函式其餘斷言不動；`load_by_id` / `enter_map` 的測試靠新 `.json` 維持綠。）

- [ ] **Step 6: 跑相關測試確認通過**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_map_manager.gd -gexit`
然後：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_maps.gd -gexit`
Expected: 兩者皆 PASS（`test_world_maps` 的 neighbors/links/entries 斷言靠忠實轉檔維持綠）。

- [ ] **Step 7: Commit**

```bash
git add autoload/map_manager.gd presentation/world/world_builder_preview.gd tests/autoload/test_map_manager.gd content/maps && git commit -m "feat(map): migrate maps to JSON; load via MapImporter (.json)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 遷移 map_builder / world_builder 測試 helper

**Files:**
- Modify: `tests/engine/map/test_map_builder.gd`, `tests/presentation/test_world_builder.gd`

**Interfaces:**
- Consumes: `MapImporter.parse(json_text)`（Task 1）。
- Produces: 無（純測試遷移）。

- [ ] **Step 1: 改 `tests/engine/map/test_map_builder.gd` 的 `_map` helper**

`tests/engine/map/test_map_builder.gd:3-4`：
```gdscript
func _map(ascii: String) -> MapData:
	return MapImporter.parse(JSON.stringify({"grid": Array(ascii.split("\n"))}))
```
（所有 test body 維持傳 ASCII 字串如 `"###\n#@#\n###"`、`"@D<>"`，不動。）

- [ ] **Step 2: 改 `tests/presentation/test_world_builder.gd` 的 `_map` helper**

`tests/presentation/test_world_builder.gd:3-4`：
```gdscript
func _map(ascii: String) -> MapData:
	return MapImporter.parse(JSON.stringify({"grid": Array(ascii.split("\n"))}))
```

- [ ] **Step 3: 跑這兩個測試確認通過**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_map_builder.gd -gexit`
然後：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_builder.gd -gexit`
Expected: 兩者皆 PASS。

- [ ] **Step 4: Commit**

```bash
git add tests/engine/map/test_map_builder.gd tests/presentation/test_world_builder.gd && git commit -m "test(map): port map_builder/world_builder helpers to MapImporter

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 移除舊 MapAsciiImporter + 全套件驗收

**Files:**
- Delete: `engine/map/map_ascii_importer.gd`（+ `.uid`）、`tests/engine/map/test_map_ascii_importer.gd`（+ `.uid`）

**Interfaces:**
- Consumes: 無新增。
- Produces: 無 `MapAsciiImporter` 殘留參照；全測試套件綠燈。

- [ ] **Step 1: 確認已無 `MapAsciiImporter` 參照**（除即將刪除的兩檔外）

Run: `grep -rn "MapAsciiImporter" --include=*.gd .`
Expected: 僅剩 `engine/map/map_ascii_importer.gd`（class 宣告）與 `tests/engine/map/test_map_ascii_importer.gd`。若有其他檔出現，先回頭修正再繼續。

- [ ] **Step 2: 刪除舊 importer 與其舊測試**

```bash
rm engine/map/map_ascii_importer.gd engine/map/map_ascii_importer.gd.uid tests/engine/map/test_map_ascii_importer.gd tests/engine/map/test_map_ascii_importer.gd.uid
```

- [ ] **Step 3: 確認沒有殘留 `.txt` 地圖參照**

Run: `grep -rn "maps/.*\.txt\|\.txt\"" --include=*.gd autoload presentation engine tests`
Expected: 無輸出（所有地圖路徑已改 `.json`）。

- [ ] **Step 4: 跑全測試套件確認全綠**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 0 failing、0 errors、0 orphans 相關失敗；通過率 100%（測試數會因移除舊 importer 測試 + 新增 `test_map_importer` 而與 M7 結束時的 278 略有出入，重點是**全綠**）。

- [ ] **Step 5: 手動 smoke（呈現層，照本專案慣例）**

Run: `./run.sh`
驗證（應與遷移前行為完全一致）：
1. 角色在起始地圖移動；踩到怪物格觸發戰鬥。
2. 走出野外邊緣接到鄰圖（保持面向、同側位置）。
3. 踩入口格進城（`town_portal` / 城鎮 portal）、出現到達訊息；城鎮走回野外正確 `entry`。
4. 存檔後讀回位置正確。
若任何一項與遷移前不同 → 視為回歸，回頭修正對應地圖 JSON 或 importer。

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor(map): remove MapAsciiImporter; JSON map format complete

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review（plan 對照 spec）

**1. Spec coverage**
- JSON 容器 + grid 字串陣列 + entities → Task 1（parser）+ Task 2（地圖檔）。✅
- importer 更名 `MapImporter` → Task 1（建立）+ Task 4（刪舊）。✅
- 副檔名 `.txt`→`.json`、MapManager 接線 → Task 2。✅
- 怪物→encounter、portal→link 對映 → Task 1（`_parse_entities`）。✅
- `@`→start + `entries["start"]` → Task 1（`parse`）。✅
- 嚴格驗證「違規→null」、未知 entity type→null、字母→未知字元 → Task 1 測試與實作。✅
- 6 張地圖轉檔 → Task 2。✅
- 測試遷移（importer/map_manager/map_builder/world_builder）+ 其餘維持綠 → Task 1/2/3 + Task 4 全套件。✅
- 非目標（不加 chest、不動 save v3、不做 .tres bake、MapData 不加欄位）→ 計畫未觸及這些，符合。✅

**2. Placeholder scan**：無 TBD/TODO；每個 code step 皆含完整程式碼與精確指令。✅

**3. Type consistency**：`MapImporter.parse(String) -> MapData` 全程一致；helper 回傳型別（`_parse_grid -> Dictionary({})`、`_parse_entities -> Variant(null|{encounters,links})`、`_parse_pos -> Variant(null|Vector2i)`）在實作與呼叫端一致；`MapData` 欄位名（`encounters`/`links`/`entries`/`neighbors`/`display_name`/`theme_id`/`start_pos`/`start_facing`/`tiles`/`width`/`height`）與既有 `resources/map_data.gd` 相符。✅
