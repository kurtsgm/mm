# 統一 local map 尺寸（LOCAL_SIZE = 10）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓所有 local map 統一為 10×10（取代現行 5×5 / 5×6），保留現有內容（座標 ×2 重佈），刪除孤兒 dungeon level01，使無縫拼接接縫永遠對齊。

**Architecture:** 新增單一常數 `MapData.LOCAL_SIZE := 10` 作為「每張 local map 邊長」唯一來源；改寫 5 張地圖 JSON 的 `grid` 為 10×10、entity 座標一律 ×2；以內容層測試（`test_world_maps.gd`）掃描 `content/maps/` 斷言每張圖皆 `LOCAL_SIZE`×`LOCAL_SIZE` 作為源頭守門。拼接 / WorldGrid / 渲染 / minimap 全讀 `map.width/height`，統一後自動正確，**不改邏輯**。

**Tech Stack:** Godot 4.7（GDScript）、GUT 測試框架、JSON 地圖格式。

## Global Constraints

- **不改 `GridGeometry.CELL_SIZE`**：維持 `2.0`，每格世界尺寸不變。
- **不改拼接/渲染/minimap 邏輯**：`WorldStitch`、`WorldGrid`、`WorldStitchRenderer`、`MiniMap`、`MapManager` 僅讀 `width/height`，自動正確。
- **不新增內容**：怪物/寶箱/NPC/vendor 數量不變，僅 ×2 重佈位置；新空間鋪可走地板。
- **座標映射規則**：所有舊座標（含 `@` 起點、entity pos、entry pos、portal/link cell、quest reach pos）一律 `new = old * 2`。
- **不需向後相容**：直接改格式與測試，不寫遷移；舊存檔壞掉可接受（pre-release）。
- **無合成測試改動**：以手建 MapData（`_floor_map("a",3,3)` 等）測演算法的測試檔（`test_world_stitch.gd`、`test_world_grid.gd`、`test_player_controller.gd`、`test_world_stitch_renderer.gd`、`test_mini_map.gd`、`test_map_transitions.gd`、`test_overworld_monsters.gd`）**不得改動**——它們不載入真實地圖。
- **測試指令**：
  - 全套：`GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
  - 單檔：上述指令尾端加 `-gselect=<script_name.gd>`
- **溝通語言**：對使用者的說明一律繁體中文（程式碼/commit 不限）。

---

### Task 1: 新增 `MapData.LOCAL_SIZE` 常數

**Files:**
- Modify: `resources/map_data.gd`（在 enum 之後、`@export` 之前插入常數）
- Test: `tests/resources/test_map_data.gd`

**Interfaces:**
- Produces: `MapData.LOCAL_SIZE`（`int`，值 `10`）——Task 2 的守門測試會引用。

- [ ] **Step 1: 寫失敗測試**

在 `tests/resources/test_map_data.gd` 檔尾新增：

```gdscript
func test_local_size_constant_is_10():
	assert_eq(MapData.LOCAL_SIZE, 10, "每張 local map 邊長常數應為 10")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_data.gd -gexit`
Expected: FAIL（`Invalid access to constant 'LOCAL_SIZE'` 或類似——常數未定義）

- [ ] **Step 3: 加入常數**

在 `resources/map_data.gd` 第 4 行 `enum TileType { ... }` 之後插入一行（與下方 `@export var map_id` 之間留空行）：

```gdscript
enum TileType { FLOOR = 0, WALL = 1, DOOR = 2, STAIRS_UP = 3, STAIRS_DOWN = 4 }

const LOCAL_SIZE := 10   # 每張 local map 一律 LOCAL_SIZE × LOCAL_SIZE（無縫拼接需等邊長）

@export var map_id: String
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_data.gd -gexit`
Expected: PASS（全綠）

- [ ] **Step 5: Commit**

```bash
git add resources/map_data.gd tests/resources/test_map_data.gd
git commit -m "feat(map): 新增 MapData.LOCAL_SIZE 常數（=10）"
```

---

### Task 2: 5 張地圖改寫 10×10 + 內容層守門測試 + quest reach 座標

**Files:**
- Test: `tests/content/test_world_maps.gd`（升級尺寸守門 + 位置斷言全部 ×2）
- Modify: `content/maps/wild_nw.json`、`content/maps/wild_ne.json`、`content/maps/wild_se.json`、`content/maps/wild_sw.json`、`content/maps/town_oak.json`（全部改 10×10）
- Modify: `content/quests/goblin_menace.json`（reach pos ×2）

**Interfaces:**
- Consumes: `MapData.LOCAL_SIZE`（Task 1）。
- Produces: 5 張 10×10 地圖內容；後續 Task 3 的 repoint 會使用 `wild_ne` 在 `(2,2)` 的遭遇格。

**TDD 說明：** 本任務先改測試（紅）、再改內容（綠）。尺寸守門與「鎮↔野往返」測試跨多張圖耦合，故 5 張圖與 test 在同一任務內完成，commit 時整體為綠。

- [ ] **Step 1: 升級 `test_world_maps.gd`（測試先行，會變紅）**

對 `tests/content/test_world_maps.gd` 做以下修改：

(a) 將 `test_wilderness_maps_share_dimensions`（斷言 width/height==5 的整個函式）**取代**為掃描式守門：

```gdscript
func test_all_content_maps_are_local_size():
	var dir := DirAccess.open("res://content/maps")
	assert_not_null(dir, "content/maps 目錄應存在")
	dir.list_dir_begin()
	var checked := 0
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var m := _load(fname.get_basename())
			assert_not_null(m, "%s 應可載入" % fname)
			assert_eq(m.width, MapData.LOCAL_SIZE, "%s width 應為 LOCAL_SIZE" % fname)
			assert_eq(m.height, MapData.LOCAL_SIZE, "%s height 應為 LOCAL_SIZE" % fname)
			checked += 1
		fname = dir.get_next()
	dir.list_dir_end()
	assert_gt(checked, 0, "至少要檢到一張地圖")
```

(b) 將 `test_town_link_roundtrip` 改為（座標 ×2）：

```gdscript
func test_town_link_roundtrip():
	var nw := _load("wild_nw")
	assert_eq(nw.get_link(Vector2i(6, 6)), {"map": "town_oak", "entry": "gate"})
	assert_true(nw.has_entry("from_town"))
	assert_eq(nw.get_entry("from_town"), {"pos": Vector2i(4, 6), "facing": GridDirection.Dir.NORTH})
	var town := _load("town_oak")
	assert_eq(town.get_entry("gate"), {"pos": Vector2i(4, 2), "facing": GridDirection.Dir.SOUTH})
	assert_eq(town.get_link(Vector2i(4, 6)), {"map": "wild_nw", "entry": "from_town"})
```

(c) 將 `test_wild_nw_has_town_decoration` 內 `Vector2i(3, 3)` 改為 `Vector2i(6, 6)`：

```gdscript
func test_wild_nw_has_town_decoration():
	var nw := _load("wild_nw")
	assert_eq(nw.decorations.size(), 1)
	assert_eq(nw.decorations[0]["pos"], Vector2i(6, 6))
	assert_eq(nw.decorations[0]["model"], "town_oak_ext")
```

(d) 將 `test_wild_ne_has_wandering_merchant` 內 `(2, 2)` 改為 `(4, 4)`：

```gdscript
func test_wild_ne_has_wandering_merchant():
	var ne := _load("wild_ne")
	assert_true(ne.has_vendor(Vector2i(4, 4)), "流浪商人在 (4,4)")
	assert_eq(ne.get_vendor(Vector2i(4, 4))["id"], "wandering_merchant")
```

(e) 將 `test_town_oak_has_demo_chests` 內 `(1,1)`→`(2,2)`、`(3,1)`→`(6,2)`：

```gdscript
func test_town_oak_has_demo_chests():
	var town := _load("town_oak")
	assert_true(town.has_object(Vector2i(2, 2)), "普通寶箱在 (2,2)")
	assert_eq(town.get_object(Vector2i(2, 2))["gold"], 50)
	assert_true(town.has_object(Vector2i(6, 2)), "看守寶箱在 (6,2)")
	assert_eq(town.get_object(Vector2i(6, 2))["gold"], 30)
	assert_eq(town.get_object(Vector2i(6, 2))["items"], ["short_sword"])
	assert_true(town.has_encounter(Vector2i(6, 2)), "(6,2) 同格有遭遇（看守怪）")
```

(f) 將 `test_wild_sw_has_dream_wisp_encounter` 內 `(1,1)` 改為 `(2,2)`：

```gdscript
func test_wild_sw_has_dream_wisp_encounter():
	var sw := _load("wild_sw")
	assert_true(sw.has_encounter(Vector2i(2, 2)), "夢魘妖遭遇在 (2,2)")
	assert_eq(sw.get_encounter(Vector2i(2, 2)), "dw")
	assert_ne(sw.get_encounter_uid(Vector2i(2, 2)), "", "遭遇需有持久 uid")
```

`test_wilderness_2x2_neighbors_symmetric`、`test_town_oak_uses_town_theme`、`test_wilderness_maps_use_grassland_theme` **不需改動**（不涉尺寸/座標）。

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_world_maps.gd -gexit`
Expected: FAIL（地圖仍 5×5、座標仍舊值，多條斷言紅）

- [ ] **Step 3: 改寫 `content/maps/wild_nw.json`**

整檔覆寫為：

```json
{
  "name": "西北野",
  "theme": "grassland",
  "grid": [
    "..........",
    "..........",
    "..........",
    "..........",
    "....@.....",
    "..........",
    "..........",
    "..........",
    "..........",
    ".........."
  ],
  "entities": [
    { "type": "portal", "pos": [6, 6], "to": "town_oak", "entry": "gate" },
    { "type": "decoration", "pos": [6, 6], "model": "town_oak_ext", "facing": "N", "scale": 0.9 },
    { "type": "questgiver", "pos": [2, 4], "dialogue": "qg_nw_messenger" }
  ],
  "entries": { "from_town": { "pos": [4, 6], "facing": "N" } },
  "neighbors": { "east": "wild_ne", "south": "wild_sw" }
}
```

- [ ] **Step 4: 改寫 `content/maps/wild_ne.json`**

整檔覆寫為：

```json
{
  "name": "東北野",
  "theme": "grassland",
  "grid": [
    "....@.....",
    "..........",
    "..........",
    "..........",
    "..........",
    "..........",
    "..........",
    "..........",
    "..........",
    ".........."
  ],
  "neighbors": { "south": "wild_se", "west": "wild_nw" },
  "entities": [
    { "type": "vendor", "pos": [4, 4], "id": "wandering_merchant" },
    { "type": "monster", "pos": [2, 2], "encounter": "g", "id": "019f076a-1c33-702d-89f4-2bdafcf85336" },
    { "type": "chest", "pos": [6, 2], "gold": 0, "items": ["lucky_charm"] },
    { "type": "questgiver", "pos": [2, 6], "dialogue": "qg_ne_scout" }
  ]
}
```

- [ ] **Step 5: 改寫 `content/maps/wild_se.json`**

整檔覆寫為：

```json
{
  "name": "東南野",
  "theme": "grassland",
  "grid": [
    "..........",
    "..........",
    "..........",
    "..........",
    "....@.....",
    "..........",
    "..........",
    "..........",
    "..........",
    ".........."
  ],
  "neighbors": { "north": "wild_ne", "west": "wild_sw" },
  "entities": [
    { "type": "chest", "pos": [2, 2], "gold": 0, "items": ["swamp_herb"] },
    { "type": "chest", "pos": [6, 2], "gold": 0, "items": ["swamp_herb"] },
    { "type": "chest", "pos": [4, 8], "gold": 0, "items": ["swamp_herb"] },
    { "type": "monster", "pos": [2, 6], "encounter": "ps", "id": "019f0900-0000-7000-8000-0000000000a1" },
    { "type": "monster", "pos": [6, 6], "encounter": "ps", "id": "019f0900-0000-7000-8000-0000000000a2" }
  ]
}
```

- [ ] **Step 6: 改寫 `content/maps/wild_sw.json`**

整檔覆寫為：

```json
{
  "name": "西南野",
  "theme": "grassland",
  "grid": [
    "..........",
    "..........",
    "..........",
    "..........",
    "....@.....",
    "..........",
    "..........",
    "..........",
    "..........",
    ".........."
  ],
  "neighbors": { "east": "wild_se", "north": "wild_nw" },
  "entities": [
    { "type": "monster", "pos": [2, 2], "encounter": "dw", "id": "019f09c6-6aa8-71f2-a346-48d9689f7698" }
  ]
}
```

- [ ] **Step 7: 改寫 `content/maps/town_oak.json`**

整檔覆寫為（外圈 `#` 牆、內部地板；座標皆 ×2 且落在 1–8）：

```json
{
  "name": "橡鎮",
  "theme": "town",
  "grid": [
    "##########",
    "#........#",
    "#........#",
    "#........#",
    "#...@....#",
    "#........#",
    "#........#",
    "#........#",
    "#........#",
    "##########"
  ],
  "entities": [
    { "type": "portal", "pos": [4, 6], "to": "wild_nw", "entry": "from_town" },
    { "type": "chest", "pos": [2, 2], "gold": 50, "items": ["potion"] },
    { "type": "chest", "pos": [6, 2], "gold": 30, "items": ["short_sword"] },
    { "type": "monster", "pos": [6, 2], "encounter": "g", "id": "019f076a-1c32-7c88-9806-5b85b28e811d" },
    { "type": "scene", "pos": [2, 6], "dialogue": "demo_event", "once": false },
    { "type": "questgiver", "pos": [4, 2], "dialogue": "qg_oak_guard" },
    { "type": "vendor", "pos": [2, 4], "id": "oak_general_store" },
    { "type": "vendor", "pos": [6, 4], "id": "oak_mage" },
    { "type": "vendor", "pos": [6, 6], "id": "oak_temple" },
    { "type": "questgiver", "pos": [4, 8], "dialogue": "qg_margo" }
  ],
  "entries": { "gate": { "pos": [4, 2], "facing": "S" } }
}
```

- [ ] **Step 8: 更新 `content/quests/goblin_menace.json` 的 reach 座標**

把 `wild_ne` 的 reach pos 由 `[3, 3]` 改為 `[6, 6]`。將該行：

```json
    { "type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "確認巢穴最深處" },
```

改為：

```json
    { "type": "reach", "map": "wild_ne", "pos": [6, 6], "desc": "確認巢穴最深處" },
```

- [ ] **Step 9: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_world_maps.gd -gexit`
Expected: PASS（全綠；守門測試掃到 5 張圖且皆 10×10）

- [ ] **Step 10: Commit**

```bash
git add content/maps/wild_nw.json content/maps/wild_ne.json content/maps/wild_se.json content/maps/wild_sw.json content/maps/town_oak.json content/quests/goblin_menace.json tests/content/test_world_maps.gd
git commit -m "feat(map): 5 張地圖改寫 10×10（座標 ×2）+ 內容層尺寸守門測試"
```

---

### Task 3: 刪除孤兒 dungeon level01 + repoint 測試

**Files:**
- Delete: `content/maps/level01.json`
- Modify: `tests/autoload/test_map_manager.gd`（3 個載入 level01 的測試改指向 `wild_ne`）
- Modify: `tests/autoload/test_save_system_capture_apply.gd`（`level01` → `wild_ne`）

**Interfaces:**
- Consumes: Task 2 的 `wild_ne`（在 `(2,2)` 有遭遇 `g`）。

**前置事實：** `level01` 僅被測試引用，無任何 portal/neighbor/開機流程引用（已 grep 全 codebase 確認），刪除安全。`test_map_manager.gd` 的 `test_load_text_sets_current_map`（用 `load_text` 餵 3×3 合成 grid）與 `test_peek_map_*`（用 `wild_nw`/`town_oak`）**不需改**。

- [ ] **Step 1: 刪除 level01 地圖檔**

```bash
git rm content/maps/level01.json
```

- [ ] **Step 2: repoint `test_map_manager.gd`（改指向 wild_ne）**

把三個函式整體取代為：

```gdscript
func test_load_by_id_loads_map_and_sets_id():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.load_by_id("wild_ne")
	assert_not_null(map)
	assert_eq(map.map_id, "wild_ne")
	assert_eq(mm.current_map, map)
	assert_gt(mm.current_map.width, 0)
	assert_true(mm.current_map.has_encounter(Vector2i(2, 2)), "wild_ne (2,2) 應有遭遇")

func test_enter_map_clears_given_encounters():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.enter_map("wild_ne", [Vector2i(2, 2)])
	assert_not_null(map)
	assert_eq(map.map_id, "wild_ne")
	assert_false(map.has_encounter(Vector2i(2, 2)), "已清座標不應再有遭遇")
	assert_eq(mm.current_map, map)

func test_enter_map_without_cleared_keeps_encounters():
	var mm = MapManagerScript.new()
	add_child_autofree(mm)
	var map := mm.enter_map("wild_ne")
	assert_true(map.has_encounter(Vector2i(2, 2)))
```

- [ ] **Step 3: repoint `test_save_system_capture_apply.gd`（level01 → wild_ne）**

此檔將字串 `"level01"` 全數改為 `"wild_ne"`（共數處：`mm.load_by_id`、`data.map_id`、`cleared_encounters`/`explored` 的 key、以及對應 `assert_eq`/`assert_true`）。可用：

```bash
sed -i '' 's/"level01"/"wild_ne"/g' tests/autoload/test_save_system_capture_apply.gd
```

（此檔以 `mm.current_map.encounters.keys()[0]` 取遭遇格、不寫死座標，故只需換 map id。）

- [ ] **Step 4: 跑兩個受影響測試檔確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_manager.gd -gexit`
Expected: PASS

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_save_system_capture_apply.gd -gexit`
Expected: PASS

- [ ] **Step 5: 跑全套測試確認全綠**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: PASS（全綠；先前 676 條，刪 level01 載入相關項後總數略減仍全綠）

> 若任何測試紅燈：失敗訊息會精確指出寫死的尺寸或座標；依「old×2」規則修正，但**不得**改動 Global Constraints 列出的合成測試檔。

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(map): 刪除孤兒 dungeon level01 並把相關測試改指向 wild_ne"
```

- [ ] **Step 7（可選、清理）：其餘把 "level01" 當字串標籤的存檔測試改名**

下列檔僅把 `"level01"` 當不透明 map_id 字串（不載入該檔，刪檔後仍會過），為避免日後誤解「為何用不存在的地圖」可一併改名為 `"town_oak"`：`test_save_system_disk.gd`、`test_save_system_list.gd`、`test_save_system_items.gd`、`test_save_system_integration.gd`、`test_game_state.gd`、`test_game_state_objects.gd`、`test_game_state_flags.gd`、`test_save_serializer_items.gd`。此步**屬清理性質、非必要**，可跳過。若執行：逐檔 `sed -i '' 's/"level01"/"town_oak"/g' <file>`，再跑全套確認全綠並 commit。

---

## 實作後人工 gate（非 TDD 任務）

完成上述後，跑 `./run.sh` 做視覺確認（自動測試無法覆蓋）：

- 野外四張圖（wild_*）拼接**接縫無缺口、無參差**（統一 10×10 後共邊等長）。
- 走起來明顯變大（每張圖 10 格）。
- 橡鎮 portal / `from_town` 落點正確、進出鎮可往返。
- 右上 minimap 顯示正常、鄰圖拼裝正確。

## Self-Review（已執行）

- **Spec coverage：** 常數（Task 1）、5 圖改 10×10（Task 2 Step 3–7）、守門測試（Task 2 Step 1a）、quest reach ×2（Task 2 Step 8）、刪 level01（Task 3 Step 1）、loader 測試 repoint（Task 3 Step 2–3）、字串標籤清理（Task 3 Step 7 可選）——spec 各項皆有對應任務。
- **Placeholder scan：** 無 TBD/TODO；所有步驟含完整 JSON / GDScript / 指令。
- **Type consistency：** `MapData.LOCAL_SIZE`（Task 1 定義）於 Task 2 守門測試引用一致；repoint 一律使用 `wild_ne` 與其 `(2,2)` 遭遇格（與 Task 2 改寫之 wild_ne 內容一致）。
