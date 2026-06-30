# 統一拼接世界載入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把世界載入收斂成「一次拼接、所有層共用」：單一 stitch 來源（`WorldGrid.regions()`）＋單一編排（`main._rebuild_world()`），未來新內容只需一行；NPC 順帶變 region-aware（與怪物一致顯示）。

**Architecture:** `WorldGrid` 維持唯一 stitch 持有者；`WorldStitchRenderer.rebuild` 改吃注入的 `regions`（不再自算第二次 stitch）；`NpcLayer` 加純靜態 `collect(regions)` 算全域 cell；`main` 以 `_rebuild_world()` 統一驅動 renderer/monsters/npcs，4 個重建點全部改呼叫它。

**Tech Stack:** Godot 4.7、GDScript、GUT 9.7。

## Global Constraints

- 所有 subagent 一律繼承 parent model（global CLAUDE.md 禁 model override，dispatch 不傳 model 參數）。
- godot 在 PATH（`/opt/homebrew/bin/godot`, 4.7）。單檔測試：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<檔名>.gd -gexit`。全套去掉 `-gselect`。**baseline：1003 passing**。
- 不需向後相容：直接改簽章/格式並一併更新所有呼叫端與測試；不留相容層、不留 dead code。
- UI/3D 版面用比例/格座標，不寫死像素（既有慣例）。
- 給使用者的說明用繁體中文（不影響程式碼/commit）。
- 座標約定（既有，務必遵守）：`WorldStitch.place` 把**焦點圖放 `ox=0, oy=0`**、鄰圖才有偏移；全世界以「全域 cell」渲染（`GridGeometry.cell_to_world(global)`），全域 cell = region local + `Vector2i(ox, oy)`。
- 每個 task commit 前驗 branch=`feat/oak-town-mainline`。
- 純加 `class_name` 時需 `godot --headless --path . --import` 一次刷新類別快取（本計畫不新增 class_name，但 `NpcLayer.collect` 是既有類別加 static 方法，不需 import）。

---

## File Structure

- Modify `presentation/world/npc_layer.gd` — 加純靜態 `collect(regions) -> Array`。
- Modify `tests/presentation/world/test_npc_layer.gd` — 加 `collect` 測試。
- Modify `presentation/world/world_stitch_renderer.gd` — `rebuild(current_map)` → `rebuild(regions)`；移除內部 `WorldStitch.place` 與不再使用的 `loader` 欄位。
- Modify `tests/presentation/test_world_stitch_renderer.gd` — 改成自算 region 清單注入。
- Modify `presentation/world/main.gd` — `_rebuild_world()` 單一編排；4 個重建點改呼叫它；`_rebuild_monsters(regions)`/`_rebuild_npcs(regions)`。

---

## Task 1：NpcLayer.collect（region→全域 cell 的純函式）

**Files:**
- Modify: `presentation/world/npc_layer.gd`
- Test: `tests/presentation/world/test_npc_layer.gd`

**Interfaces:**
- Produces: `static func NpcLayer.collect(regions: Array) -> Array`，每項 `{pos: Vector2i(全域), sprite: String}`；輸入 `regions` = `[{map: MapData, ox: int, oy: int}]`（= `WorldGrid.regions()`）。
- 既有 `NpcLayer.build(quest_givers: Array)` 渲染端**不變**（已用 `cell_to_world(q["pos"])`，吃全域 cell 即可）。

- [ ] **Step 1: 寫失敗測試**

在 `tests/presentation/world/test_npc_layer.gd` 末端新增：

```gdscript
func _qg_map(id: String, w: int, h: int, qgs: Array) -> MapData:
	var m := MapData.new()
	m.map_id = id
	m.width = w
	m.height = h
	m.quest_givers = qgs
	return m

func test_collect_focus_region_keeps_local_pos():
	var a := _qg_map("a", 5, 5, [{"pos": Vector2i(1, 1), "dialogue": "d", "sprite": "s_a"}])
	var out := NpcLayer.collect([{"map": a, "ox": 0, "oy": 0}])
	assert_eq(out.size(), 1)
	assert_eq(out[0], {"pos": Vector2i(1, 1), "sprite": "s_a"}, "焦點區偏移 0 → 位置不變")

func test_collect_neighbor_region_applies_offset():
	var a := _qg_map("a", 5, 5, [{"pos": Vector2i(1, 1), "dialogue": "d", "sprite": "s_a"}])
	var e := _qg_map("e", 5, 5, [{"pos": Vector2i(0, 2), "dialogue": "d", "sprite": "s_e"}])
	var out := NpcLayer.collect([{"map": a, "ox": 0, "oy": 0}, {"map": e, "ox": 5, "oy": 0}])
	assert_eq(out.size(), 2)
	assert_eq(out[0], {"pos": Vector2i(1, 1), "sprite": "s_a"})
	assert_eq(out[1], {"pos": Vector2i(5, 2), "sprite": "s_e"}, "鄰區加 (ox,oy) → 全域 cell")

func test_collect_missing_sprite_defaults_empty():
	var a := _qg_map("a", 5, 5, [{"pos": Vector2i(2, 2), "dialogue": "d"}])
	var out := NpcLayer.collect([{"map": a, "ox": 0, "oy": 0}])
	assert_eq(out[0]["sprite"], "", "缺 sprite → 空字串")

func test_collect_empty_regions():
	assert_eq(NpcLayer.collect([]), [], "無 region → 空清單")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_npc_layer.gd -gexit`
Expected: FAIL（`collect` 未定義）

- [ ] **Step 3: 寫最小實作**

在 `presentation/world/npc_layer.gd` 新增 static 方法（放在檔案內、與 `build` 同層級）：

```gdscript
# 從 WorldGrid.regions()（[{map, ox, oy}]）收集所有 region（焦點+鄰圖）的 questgiver，
# 算成全域 cell 的渲染清單，與 OverworldMonsters.init_from_regions 的 region→global 慣例一致。
static func collect(regions: Array) -> Array:
	var out: Array = []
	for region in regions:
		var off := Vector2i(int(region["ox"]), int(region["oy"]))
		var m: MapData = region["map"]
		for q in m.quest_givers:
			out.append({"pos": q["pos"] + off, "sprite": String(q.get("sprite", ""))})
	return out
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_npc_layer.gd -gexit`
Expected: PASS（既有 + 新 4 筆全綠）

- [ ] **Step 5: Commit**

```bash
git add presentation/world/npc_layer.gd tests/presentation/world/test_npc_layer.gd
git commit -m "feat(npc): NpcLayer.collect 把所有 region 的 questgiver 算成全域 cell" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2：renderer 吃注入 regions + main 單一編排（整合）

把 `WorldStitchRenderer.rebuild` 改成吃注入的 `regions`，並把 `main` 的 4 個重建點收斂成單一 `_rebuild_world()`。renderer 簽章與其呼叫端**必須一起改**（否則樹會壞），故同一個 task。

**Files:**
- Modify: `presentation/world/world_stitch_renderer.gd`
- Modify: `tests/presentation/test_world_stitch_renderer.gd`
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes: `WorldGrid.regions() -> Array`（`[{map, ox, oy}]`）、`NpcLayer.collect(regions)`（U1）、`OverworldMonsters.init_from_regions(regions, is_defeated, saved_provider)`（既有）。
- Changes: `WorldStitchRenderer.rebuild(current_map: MapData)` → `rebuild(regions: Array)`；移除 `loader` 欄位。

此 task 無法用單元測試覆蓋 main 整合；gate＝renderer 單檔測試綠 + 全套綠 + 開機 smoke 乾淨。

- [ ] **Step 1: 改 renderer 測試（先 RED）**

`tests/presentation/test_world_stitch_renderer.gd`：在 helper 區新增一個自算 region 清單的 helper（沿用測試自己的 `_loader`）：

```gdscript
func _regions_for(current: MapData) -> Array:
	var win := WorldStitch.window_for(current)
	return WorldStitch.place(current, Callable(self, "_loader"), win["half"], win["center"])
```

把 `_renderer()` 內的 `r.loader = Callable(self, "_loader")` 這行**刪除**（`loader` 欄位將移除）。同樣刪除 `test_default_path_*` / `test_refresh_objects_*` 三個直接 new renderer 的測試裡的 `r.loader = Callable(self, "_loader")` 行。

把每一處 `r.rebuild(<map>)` 改成 `r.rebuild(_regions_for(<map>))`，逐一對應：
- `test_single_map_one_container_at_origin`: `r.rebuild(_regions_for(a))`
- `test_east_neighbor_container_offset`: `r.rebuild(_regions_for(a))`
- `test_pooling_reuses_region_node_across_rebuild`: 兩處 `r.rebuild(_regions_for(a))`
- `test_reused_container_repositioned_when_current_region_changes`: `r.rebuild(_regions_for(a))` 與 `r.rebuild(_regions_for(e))`
- `test_pooling_frees_departed_region`: `r.rebuild(_regions_for(a))` 與 `r.rebuild(_regions_for(far))`
- `test_default_path_builds_real_worldbuilder_and_objectlayer`: `r.rebuild(_regions_for(a))`
- `test_default_path_builds_chest_layer`: `r.rebuild(_regions_for(a))`
- `test_refresh_objects_rebuilds_chest_layer`: `r.rebuild(_regions_for(a))`（`refresh_objects(a)` 不變）

- [ ] **Step 2: 跑 renderer 測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_stitch_renderer.gd -gexit`
Expected: FAIL（`rebuild` 仍吃 `current_map`／`loader` 欄位仍在 → 與新測試不一致；具體紅法可能是 place 在 renderer 內被重算或型別不符）

- [ ] **Step 3: 改 renderer 實作**

`presentation/world/world_stitch_renderer.gd`：

- 刪除 `var loader: Callable = Callable(MapManager, "peek_map")` 這行（rebuild 不再自算，loader 變 dead code）。
- 把 `rebuild` 改成吃注入 regions：

```gdscript
func rebuild(regions: Array) -> void:
	# regions = [{map, ox, oy}]（WorldGrid.regions()，單一 stitch 來源）。不再自算第二次 stitch。
	var keep := {}
	for node in regions:
		keep[node["map"].map_id] = true
	# 清掉離開的區域
	for id in _regions.keys():
		if not keep.has(id):
			_regions[id].free()
			_regions.erase(id)
	# 沿用/新建 + 重定位（沿用者偏移也會隨目前區域改變 → 無縫跨界不變式）
	for node in regions:
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
```

`_build_content` / `refresh_objects` / `_opened_set` / `region_builder` / `opened_provider` **不變**。檔頭註解第 6 行「目前區域用傳入的 live current_map；鄰區用 loader（peek_map）」改成「regions 由 WorldGrid 注入（焦點為 live、鄰圖為 peek，與 grid 同源）」。

- [ ] **Step 4: 跑 renderer 測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_stitch_renderer.gd -gexit`
Expected: PASS

- [ ] **Step 5: 改 main 編排（單一 `_rebuild_world`）**

先 grep 確認 renderer 呼叫端只在 main：`grep -rn "_world_renderer.rebuild" presentation/`（應只剩 main；若有他處一併改）。

`presentation/world/main.gd`：

(a) 新增/收斂 helper（取代既有 `_rebuild_monsters_for_current_map` / `_rebuild_npcs_for_current_map`）：

```gdscript
# 單一世界載入編排：一次 stitch（_build_world_grid）→ regions → 所有層共用。
# 未來新世界內容：在此加一行 _x.build(regions) 即可，不必再碰各重建點。
func _rebuild_world() -> void:
	_build_world_grid()
	var regions := _world_grid.regions()
	_world_renderer.rebuild(regions)
	_rebuild_monsters(regions)
	_rebuild_npcs(regions)

func _rebuild_monsters(regions: Array) -> void:
	_overworld_monsters = OverworldMonsters.new()
	_overworld_monsters.init_from_regions(regions, Callable(GameState, "is_defeated"), Callable(self, "_saved_monster_state"))
	_monster_layer.rebuild(_overworld_monsters.live())

func _rebuild_npcs(regions: Array) -> void:
	_npc_layer.build(NpcLayer.collect(regions))
```

刪除舊的 `_rebuild_monsters_for_current_map()` 與 `_rebuild_npcs_for_current_map()`。

(b) setup（建層處）：把「建 renderer/monster/npc 節點」保留為一次性 `new()`+`add_child`，其後改呼叫 `_rebuild_world()`。setup 內原本的 `_world_renderer.rebuild(...)` / `_build_world_grid()` / `_rebuild_monsters_for_current_map()` / `_rebuild_npcs_for_current_map()` 全部移除，改成：

```gdscript
	_world_renderer = WorldStitchRenderer.new()
	add_child(_world_renderer)
	_monster_layer = MonsterLayer.new()
	add_child(_monster_layer)
	_npc_layer = NpcLayer.new()
	add_child(_npc_layer)
	_rebuild_world()
```

（確保三個 layer 節點都先建立，`_rebuild_world()` 才去填內容。MonsterLayer/NpcLayer 的宣告與原本一致。）

(c) `_recenter_to`：把 `_build_world_grid()` / `_world_renderer.rebuild(...)` / `_rebuild_monsters_for_current_map()` / `_rebuild_npcs_for_current_map()` 換成單一 `_rebuild_world()`，並保留其後的 `_player.rebase(delta, _world_grid)`（rebase 在 `_rebuild_world()` 之後，因為它需要新的 `_world_grid`）：

```gdscript
	MapManager.enter_map(map_id, GameState.cleared_for(map_id))
	_rebuild_world()
	_player.rebase(delta, _world_grid)
	GameState.current_map_id = map_id
```

(d) `_enter_via_link`（link 重建點）：把該段 renderer/grid/monsters/npcs 換成 `_rebuild_world()`，保留其後 `_player.setup(...)`。

(e) `_on_loaded`（load 重建點）：換成 `_rebuild_world()`，其後接 `_world_renderer.refresh_objects(MapManager.current_map)`（維持原本「載入後刷新寶箱」順序：refresh 必須在 rebuild 之後），再接 `_player.setup(...)`。

- [ ] **Step 6: 全套測試 + 開機 smoke**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全綠（baseline 1003 + U1 的 4 筆；renderer 測試改寫後仍綠），無 `_rebuild_monsters_for_current_map`/`_rebuild_npcs_for_current_map` 殘留參考。
Then: `./run.sh --headless`
Expected: 乾淨啟動、無 script error、自行退出（exit 0）。

並 grep 確認無殘留：`grep -rn "_rebuild_monsters_for_current_map\|_rebuild_npcs_for_current_map\|\.loader" presentation/world/main.gd presentation/world/world_stitch_renderer.gd`（應為空或只剩無關項）。

- [ ] **Step 7: Commit**

```bash
git add presentation/world/world_stitch_renderer.gd tests/presentation/test_world_stitch_renderer.gd presentation/world/main.gd
git commit -m "refactor(world): 單一 stitch 來源 + _rebuild_world 統一編排（renderer 吃注入 regions，NPC region-aware）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 最終人工視覺 gate（`./run.sh`）

1. 站在 wild_nw 往 wild_ne 方向看：鄰圖的**斥候 NPC** 與鄰圖的怪**一起顯示**（不再只看到怪、不再 NPC pop-in）。
2. 跨界進 wild_ne：無縫、NPC 位置正確、可 bump 對話。
3. 橡鎮 4 個 NPC、寶箱、城鎮外觀一切如常（renderer 改注入後行為不變）。
4. 存檔/讀檔後世界正確重建（`_on_loaded` 走 `_rebuild_world` + refresh_objects）。
