# 任務 NPC 呈現 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓任務 NPC 在第一人稱世界以人物立繪 billboard 站立呈現、撞上去就開對話，並把對話視窗改成近滿版羊皮紙（上 70% 情境圖／下 30% 對話）。

**Architecture:** 世界端新增 `NpcSpriteCatalog`＋`NpcLayer`（鏡射怪物 billboard）；`WorldGrid` 把 questgiver 格標為實心並建 region-aware 的 occupant 表；`player_controller` 撞牆時 emit `bumped`，`main` 查 occupant 為 questgiver → 開對話（移除舊的踩格觸發）；`DialogueOverlay` 改羊皮紙 70/30 版面。

**Tech Stack:** Godot 4.7、GDScript、GUT 9.7 測試。

## Global Constraints

- 美術一律遵循 `docs/art-style-guide.md`（半寫實、固定暖光、去背 alpha PNG）。NPC 立繪與對話情境圖皆然。
- UI 版面一律 anchor 比例、解析度無關，不寫死像素（字級可固定）。
- 不需向後相容：直接改 schema／存檔／資料格式並一併更新呼叫端與內容，舊存檔壞掉沒關係。
- 給使用者的說明用繁體中文（不影響程式碼／commit）。
- Sub-agent 一律繼承 parent model，不得指定模型覆蓋。
- 單檔測試：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<file>.gd -gexit`
- 全套測試：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`（目前 baseline：978 passing）
- 開機 smoke：`./run.sh --headless`（乾淨啟動、無 script error、自行退出）

---

## File Structure

- Create `presentation/world/npc_sprite_catalog.gd` — `NpcSpriteCatalog`：npc_id → {idle, idle2} 貼圖，缺檔回 null。
- Create `presentation/world/npc_layer.gd` — `NpcLayer`：每個 questgiver 一個站立 billboard `Sprite3D`，idle 兩幀／晃動。
- Create `tests/presentation/world/test_npc_sprite_catalog.gd`、`tests/presentation/world/test_npc_layer.gd`。
- Modify `engine/world/world_grid.gd` — questgiver 格不可走 + `_occupants` 表 + `occupant_at()`。
- Modify `engine/map/map_importer.gd` — questgiver 解析帶 `sprite`。
- Modify `resources/map_data.gd` — `quest_givers` 註解補 `sprite`。
- Modify `presentation/world/player_controller.gd` — 新 `bumped(cell)` signal。
- Modify `presentation/world/main.gd` — 建 `_npc_layer`、3 個重建點、接 `bumped` 開對話、移除踩格觸發。
- Modify `presentation/ui/dialogue_overlay.gd` — 羊皮紙 70/30 版面。
- Create `content/ui/parchment_dialogue.png`（用 `tools/gen_parchment.gd` 生）。
- Modify `tools/quest_lint.gd` — questgiver 擺位規則 + `questgiver_placement_errors()`。
- Modify `content/maps/{town_oak,wild_nw,wild_ne,int_oak_smithy}.json` — questgiver 加 `sprite`。

---

## Task 1：NpcSpriteCatalog

**Files:**
- Create: `presentation/world/npc_sprite_catalog.gd`
- Test: `tests/presentation/world/test_npc_sprite_catalog.gd`

**Interfaces:**
- Produces: `NpcSpriteCatalog.textures_for(npc_id: String) -> Dictionary`（回 `{idle: Texture2D|null, idle2: Texture2D|null}`）。

- [ ] **Step 1: 寫失敗測試**

Create `tests/presentation/world/test_npc_sprite_catalog.gd`：

```gdscript
extends GutTest

func test_unregistered_npc_returns_null_pair():
	var t := NpcSpriteCatalog.textures_for("nobody")
	assert_null(t["idle"], "未註冊 → idle null")
	assert_null(t["idle2"], "未註冊 → idle2 null")

func test_always_has_idle_and_idle2_keys():
	var t := NpcSpriteCatalog.textures_for("nobody")
	assert_true(t.has("idle") and t.has("idle2"), "兩個 key 一律齊備")

func test_missing_path_resolves_to_null():
	var out := NpcSpriteCatalog._resolve_spec({"idle": "res://does/not/exist.png"})
	assert_null(out["idle"], "路徑指向不存在的檔 → null")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_npc_sprite_catalog.gd -gexit`
Expected: FAIL（`NpcSpriteCatalog` 未定義）

- [ ] **Step 3: 寫最小實作**

Create `presentation/world/npc_sprite_catalog.gd`：

```gdscript
class_name NpcSpriteCatalog
extends Object

# npc_id → 兩態貼圖路徑（idle/idle2）。鏡射 MonsterSpriteCatalog 的「id→資源路徑對照表」慣例。
# 未註冊／缺檔 → null（由 NpcLayer fallback 成 placeholder）；idle2 缺則退回微幅晃動。
# 內容期逐 NPC 填入；貼圖為去背 alpha PNG（同畫風、同框同比例，見 docs/art-style-guide.md）。
const _SPRITES := {}

static func textures_for(npc_id: String) -> Dictionary:
	if not _SPRITES.has(npc_id):
		return {"idle": null, "idle2": null}
	return _resolve_spec(_SPRITES[npc_id])

# 純路徑解析：路徑非空且存在則 load，否則 null。
static func _resolve_spec(spec: Dictionary) -> Dictionary:
	var out := {"idle": null, "idle2": null}
	for key in out:
		var path := String(spec.get(key, ""))
		if path != "" and ResourceLoader.exists(path):
			out[key] = load(path)
	return out
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_npc_sprite_catalog.gd -gexit`
Expected: PASS（3/3）

- [ ] **Step 5: Commit**

```bash
git add presentation/world/npc_sprite_catalog.gd presentation/world/npc_sprite_catalog.gd.uid tests/presentation/world/test_npc_sprite_catalog.gd
git commit -m "feat(npc): NpcSpriteCatalog（npc_id→idle/idle2 貼圖，缺檔回 null）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2：NpcLayer（站立 billboard）

**Files:**
- Create: `presentation/world/npc_layer.gd`
- Test: `tests/presentation/world/test_npc_layer.gd`

**Interfaces:**
- Consumes: `NpcSpriteCatalog.textures_for`、`MonsterLayer`（const `PHASE_SPREAD/FRAME_PERIOD/SWAY_WORLD/SWAY_PERIOD` 與 static `frame_index/sway_offset_px`）、`CombatStage.DISPLAY_HEIGHT`、`CombatStage.pixel_size_for`、`GridGeometry.cell_to_world`。
- Produces: `NpcLayer.build(quest_givers: Array) -> void`（每項 `{pos: Vector2i, dialogue: String, sprite: String}`）；內部 `_sprites: Array`（member dict `{node, a, b, phase, cur}`）。

- [ ] **Step 1: 寫失敗測試**

Create `tests/presentation/world/test_npc_layer.gd`：

```gdscript
extends GutTest

func _layer() -> NpcLayer:
	var l := NpcLayer.new()
	add_child_autofree(l)
	return l

func _qg(pos: Vector2i, sprite := "") -> Dictionary:
	return {"pos": pos, "dialogue": "d", "sprite": sprite}

func test_build_one_sprite_per_questgiver():
	var l := _layer()
	l.build([_qg(Vector2i(1, 1)), _qg(Vector2i(2, 3))])
	assert_eq(l._sprites.size(), 2, "兩個 questgiver → 兩個 member")
	assert_eq(l.get_child_count(), 2, "兩個 Sprite3D 進場景")

func test_build_clears_previous():
	var l := _layer()
	l.build([_qg(Vector2i(0, 0)), _qg(Vector2i(1, 0))])
	l.build([_qg(Vector2i(2, 0))])
	assert_eq(l._sprites.size(), 1, "重建只剩新的")
	assert_eq(l.get_child_count(), 1, "舊 sprite 已釋放")

func test_sprite_uses_billboard():
	var l := _layer()
	l.build([_qg(Vector2i(0, 0))])
	assert_eq(l._sprites[0]["node"].billboard, BaseMaterial3D.BILLBOARD_ENABLED)

func test_feet_on_floor_and_centered_on_cell():
	var l := _layer()
	var cell := Vector2i(1, 2)
	l.build([_qg(cell)])
	var s: Sprite3D = l._sprites[0]["node"]
	var w := GridGeometry.cell_to_world(cell)
	assert_almost_eq(s.position.y, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0001, "腳貼地")
	assert_almost_eq(s.position.x, w.x, 0.0001)
	assert_almost_eq(s.position.z, w.z, 0.0001)

func test_unregistered_sprite_uses_non_null_placeholder():
	var l := _layer()
	l.build([_qg(Vector2i(0, 0), "no_such_npc")])
	assert_not_null(l._sprites[0]["node"].texture, "placeholder 非 null")

func test_build_enables_processing_when_present_and_off_when_empty():
	var l := _layer()
	l.build([_qg(Vector2i(0, 0))])
	assert_true(l.is_processing(), "有 NPC → idle 動畫常駐")
	l.build([])
	assert_false(l.is_processing(), "無 NPC → 關 process")

func test_distinct_incrementing_phases():
	var l := _layer()
	l.build([_qg(Vector2i(0, 0)), _qg(Vector2i(1, 0))])
	assert_almost_eq(l._sprites[0]["phase"], 0.0, 0.0001)
	assert_almost_eq(l._sprites[1]["phase"], MonsterLayer.PHASE_SPREAD, 0.0001)

func test_process_sway_is_horizontal_only_for_placeholder():
	var l := _layer()
	l.build([_qg(Vector2i(0, 0), "no_such_npc")])   # 無 idle2 → 晃動 fallback
	l._process(0.016)
	var s: Sprite3D = l._sprites[0]["node"]
	var max_px: float = MonsterLayer.SWAY_WORLD / s.pixel_size
	assert_lt(absf(s.offset.x), max_px + 0.0001, "晃動不超過世界振幅換算")
	assert_almost_eq(s.offset.y, 0.0, 0.0001, "只左右、不上下")

func test_update_member_swaps_texture_when_second_frame_present():
	var l := _layer()
	l.build([_qg(Vector2i(0, 0))])
	var member: Dictionary = l._sprites[0]
	var tex_b := ImageTexture.create_from_image(Image.create(32, 48, false, Image.FORMAT_RGBA8))
	member["b"] = tex_b
	member["cur"] = 0
	member["phase"] = 0.0
	l._update_member(member, MonsterLayer.FRAME_PERIOD)   # idx=1 → 切到 b
	assert_eq(member["node"].texture, tex_b, "有第二幀 → 切到 frame B")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_npc_layer.gd -gexit`
Expected: FAIL（`NpcLayer` 未定義）

- [ ] **Step 3: 寫最小實作**

Create `presentation/world/npc_layer.gd`：

```gdscript
class_name NpcLayer
extends Node3D

# 任務 NPC 的站立 billboard 層。每個 questgiver 一個 Sprite3D，腳貼地、面向鏡頭、原大小（無 cluster）。
# idle 生命感：有 idle2 → 兩幀輪播；否則微幅左右晃動。複用 MonsterLayer 的純函式/常數與 CombatStage 尺寸。
# 跟著切地圖由 main.gd rebuild。NPC 不移動，故無 apply_moves。

# member = { node:Sprite3D, a:Texture2D, b:Texture2D|null, phase:float, cur:int }
var _sprites: Array = []

func build(quest_givers: Array) -> void:
	_clear()
	var phase_seed := 0
	for q in quest_givers:
		var fr := _frames_for(String(q.get("sprite", "")))
		_sprites.append(_make_sprite(fr["a"], fr["b"], q["pos"], phase_seed))
		phase_seed += 1
	set_process(not _sprites.is_empty())   # idle 動畫常駐（有 NPC 才開）

func _make_sprite(a: Texture2D, b, cell: Vector2i, phase_seed: int) -> Dictionary:
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_apply_texture(s, a)
	s.position = GridGeometry.cell_to_world(cell) + Vector3(0.0, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0)
	add_child(s)
	return {"node": s, "a": a, "b": b, "phase": phase_seed * MonsterLayer.PHASE_SPREAD, "cur": 0}

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for member in _sprites:
		if is_instance_valid(member["node"]):
			_update_member(member, t)

# 有第二幀（idle2）→ 兩幀輪播；否則 → 微幅左右晃動 fallback。與 position 獨立。
func _update_member(member: Dictionary, t: float) -> void:
	var s: Sprite3D = member["node"]
	if member["b"] != null:
		var idx := MonsterLayer.frame_index(t, member["phase"] / TAU, MonsterLayer.FRAME_PERIOD)
		if idx != member["cur"]:
			_apply_texture(s, member["b"] if idx == 1 else member["a"])
			member["cur"] = idx
	else:
		s.offset = Vector2(MonsterLayer.sway_offset_px(t, member["phase"], MonsterLayer.SWAY_WORLD, MonsterLayer.SWAY_PERIOD, s.pixel_size), 0.0)

# 某 sprite id 的兩幀：idle(真圖/placeholder)=a、idle2=b（可 null → 退回晃動）。
func _frames_for(sprite_id: String) -> Dictionary:
	var ph := _placeholder(Color(0.45, 0.55, 0.75))   # 中性藍灰（與怪物紅方塊區隔）
	var tx = NpcSpriteCatalog.textures_for(sprite_id)
	var a = tx["idle"] if tx["idle"] != null else ph
	return {"a": a, "b": tx.get("idle2", null)}

func _apply_texture(s: Sprite3D, tex: Texture2D) -> void:
	s.texture = tex
	s.pixel_size = CombatStage.pixel_size_for(tex, CombatStage.DISPLAY_HEIGHT)

func _placeholder(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_sprites.clear()
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_npc_layer.gd -gexit`
Expected: PASS（9/9）

- [ ] **Step 5: Commit**

```bash
git add presentation/world/npc_layer.gd presentation/world/npc_layer.gd.uid tests/presentation/world/test_npc_layer.gd
git commit -m "feat(npc): NpcLayer 站立 billboard（腳貼地/billboard/idle 兩幀/晃動 fallback）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3：WorldGrid — questgiver 實心 + occupant 表

**Files:**
- Modify: `engine/world/world_grid.gd`
- Test: `tests/engine/world/test_world_grid.gd`

**Interfaces:**
- Consumes: `MapData.quest_givers`（`[{pos: Vector2i, dialogue: String, ...}]`）。
- Produces: `WorldGrid.occupant_at(global: Vector2i) -> Dictionary`（questgiver 格回 `{kind:"questgiver", dialogue:<id>}`，否則 `{}`）；questgiver 格 `is_walkable` 變 false。

- [ ] **Step 1: 寫失敗測試**

在 `tests/engine/world/test_world_grid.gd` 末端新增：

```gdscript
func _qg_map(id: String, w: int, h: int, qgs: Array, neighbors := {}) -> MapData:
	var m := _floor_map(id, w, h, neighbors)
	m.quest_givers = qgs
	return m

func test_questgiver_cell_not_walkable_and_occupant():
	var a := _qg_map("a", 3, 3, [{"pos": Vector2i(1, 1), "dialogue": "qg_x"}])
	var wg := WorldGrid.new(a, Callable(self, "_null_loader"))
	assert_false(wg.is_walkable(Vector2i(1, 1)), "questgiver 格實心不可走")
	assert_eq(wg.occupant_at(Vector2i(1, 1)), {"kind": "questgiver", "dialogue": "qg_x"})
	assert_eq(wg.resolve(Vector2i(1, 1)), {"map_id": "a", "local": Vector2i(1, 1)}, "仍可反查")

func test_no_occupant_returns_empty():
	var a := _floor_map("a", 3, 3)
	var wg := WorldGrid.new(a, Callable(self, "_null_loader"))
	assert_eq(wg.occupant_at(Vector2i(1, 1)), {}, "無 NPC 格回空")

func test_questgiver_in_neighbor_region_occupant_resolved():
	var a := _floor_map("a", 3, 3, {GridDirection.Dir.EAST: "e"})
	var e := _qg_map("e", 3, 3, [{"pos": Vector2i(0, 1), "dialogue": "qg_e"}], {GridDirection.Dir.WEST: "a"})
	_world = {"a": a, "e": e}
	var wg := WorldGrid.new(a, Callable(self, "_loader"))
	# e 在 ox=3 → 其 local (0,1) = global (3,1)
	assert_eq(wg.occupant_at(Vector2i(3, 1)), {"kind": "questgiver", "dialogue": "qg_e"})
	assert_false(wg.is_walkable(Vector2i(3, 1)), "鄰圖 questgiver 也實心")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_grid.gd -gexit`
Expected: FAIL（`occupant_at` 未定義）

- [ ] **Step 3: 寫最小實作**

在 `engine/world/world_grid.gd` 第 9 行 `_regions` 宣告後新增欄位：

```gdscript
var _occupants: Dictionary = {}  # Vector2i(global) -> { "kind": String, "dialogue": String }
```

在 `_init` 的 region 迴圈，把 `for y in m.height:` ... 那段 cell 迴圈**之後**（仍在 `for region in _regions:` 內）加上 questgiver pass：

```gdscript
		for q in m.quest_givers:
			var qg: Vector2i = q["pos"] + Vector2i(ox, oy)
			if _occupants.has(qg):
				continue   # 第一寫入者勝（與 _owner 同確定性規則）
			_occupants[qg] = {"kind": "questgiver", "dialogue": String(q["dialogue"])}
			_walkable.erase(qg)   # NPC 實心擋路：占用格不可走（牆格 erase 為 no-op）
```

在 `is_walkable` 後新增：

```gdscript
func occupant_at(global: Vector2i) -> Dictionary:
	return _occupants.get(global, {})
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_world_grid.gd -gexit`
Expected: PASS（原有 + 新 3 筆全綠）

- [ ] **Step 5: Commit**

```bash
git add engine/world/world_grid.gd tests/engine/world/test_world_grid.gd
git commit -m "feat(world): WorldGrid questgiver 格實心 + region-aware occupant 表" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4：map_importer 解析 questgiver `sprite`

**Files:**
- Modify: `engine/map/map_importer.gd:175-178`
- Modify: `resources/map_data.gd:25`（註解）
- Test: `tests/engine/map/test_map_importer.gd`

**Interfaces:**
- Produces: `MapData.quest_givers` 每項多 `sprite: String`（缺省 `""`）。

- [ ] **Step 1: 寫失敗測試**

在 `tests/engine/map/test_map_importer.gd` 末端新增：

```gdscript
func test_questgiver_parses_sprite_field():
	var json := JSON.stringify({
		"name": "t", "theme": "town",
		"grid": ["###", "#.#", "###"],
		"entities": [{"type": "questgiver", "pos": [1, 1], "dialogue": "qg_x", "sprite": "oak_guard"}],
	})
	var m = MapImporter.parse(json)
	assert_not_null(m)
	assert_eq(m.quest_givers.size(), 1)
	assert_eq(m.quest_givers[0]["sprite"], "oak_guard", "解析帶上 sprite")

func test_questgiver_sprite_defaults_empty():
	var json := JSON.stringify({
		"name": "t", "theme": "town",
		"grid": ["###", "#.#", "###"],
		"entities": [{"type": "questgiver", "pos": [1, 1], "dialogue": "qg_x"}],
	})
	var m = MapImporter.parse(json)
	assert_eq(m.quest_givers[0]["sprite"], "", "缺 sprite → 空字串")
```

> 註：若上述 inline grid 格式與既有 `test_map_importer.gd` 的建圖 helper 不同，改用該檔既有的 helper 建圖、只在 entities 裡放 questgiver；重點是斷言 `quest_givers[0]["sprite"]`。

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_map_importer.gd -gexit`
Expected: FAIL（`sprite` key 不存在）

- [ ] **Step 3: 寫最小實作**

`engine/map/map_importer.gd` 的 questgiver 分支改為：

```gdscript
			"questgiver":
				if not e.has("dialogue"):
					return null
				quest_givers.append({"pos": pos, "dialogue": String(e["dialogue"]), "sprite": String(e.get("sprite", ""))})
```

`resources/map_data.gd:25` 註解更新為：

```gdscript
@export var quest_givers: Array = []       # [{ pos:Vector2i, dialogue:String, sprite:String }]
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_map_importer.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add engine/map/map_importer.gd resources/map_data.gd tests/engine/map/test_map_importer.gd
git commit -m "feat(map): questgiver 解析帶 sprite 欄（世界立繪 id）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5：player_controller 新 `bumped` signal

**Files:**
- Modify: `presentation/world/player_controller.gd`
- Test: `tests/presentation/test_player_controller.gd`

**Interfaces:**
- Produces: `signal bumped(cell: Vector2i)`——`_attempt_move` 撞到不可走目標格時 emit 該目標全域 cell。

- [ ] **Step 1: 寫失敗測試**

在 `tests/presentation/test_player_controller.gd` 末端新增：

```gdscript
func test_blocked_move_emits_bumped_with_target():
	var pc := _make_pc(_wg(_with_wall(_floor_map("a", 3, 3), Vector2i(1, 0))), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)   # 北 → (1,0) 是牆
	assert_signal_emitted_with_parameters(pc, "bumped", [Vector2i(1, 0)])

func test_successful_move_does_not_emit_bumped():
	var pc := _make_pc(_wg(_floor_map("a", 3, 3)), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)   # (1,0) 可走
	assert_signal_not_emitted(pc, "bumped")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_player_controller.gd -gexit`
Expected: FAIL（`bumped` 未宣告 / 未 emit）

- [ ] **Step 3: 寫最小實作**

在 `presentation/world/player_controller.gd` 既有 signal 宣告處（`entered_cell` 旁）新增：

```gdscript
signal bumped(cell: Vector2i)
```

`_attempt_move` 的擋牆分支改為：

```gdscript
	if not _world_grid.is_walkable(target):
		bumped.emit(target)
		return false   # 牆/實心 NPC（含外緣無鄰）→ 不動；main 端決定 bump 是否觸發互動
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_player_controller.gd -gexit`
Expected: PASS（含既有 wall 測試仍綠）

- [ ] **Step 5: Commit**

```bash
git add presentation/world/player_controller.gd tests/presentation/test_player_controller.gd
git commit -m "feat(player): 撞不可走格時 emit bumped(target)（供 NPC 互動）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6：main.gd 接線 — NpcLayer 重建 + bump 開對話 + 移除踩格觸發

**Files:**
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes: `NpcLayer.build`、`WorldGrid.occupant_at`、`PlayerController.bumped`、`MapManager.current_map.quest_givers`、`DialogueCatalog.load_dialogue`、`DialogueRunner`、`_dialogue_overlay`。

此為整合任務（無單元測試）；gate＝全套測試綠 + 開機 smoke 乾淨。

- [ ] **Step 1: 宣告 NpcLayer 欄位**

在 `_monster_layer` 宣告（約第 23 行）下方新增：

```gdscript
var _npc_layer: NpcLayer
```

- [ ] **Step 2: setup 建層並首次建 NPC**

在 setup 內 `_rebuild_monsters_for_current_map()`（約第 54 行）**之後**新增：

```gdscript
	_npc_layer = NpcLayer.new()
	add_child(_npc_layer)
	_rebuild_npcs_for_current_map()
```

- [ ] **Step 3: 連接 bumped**

在 `_player.entered_cell.connect(...)` / `_player.facing_changed.connect(...)`（約第 61-62 行）旁新增：

```gdscript
	_player.bumped.connect(_on_player_bumped)
```

- [ ] **Step 4: 新增 NPC 重建 helper，並在另外兩個重建點呼叫**

在 `_rebuild_monsters_for_current_map()` 函式（約第 257 行）下方新增：

```gdscript
func _rebuild_npcs_for_current_map() -> void:
	_npc_layer.build(MapManager.current_map.quest_givers)
```

在 `_recenter_to` 的 `_rebuild_monsters_for_current_map()` 之後（約第 185 行）新增一行 `_rebuild_npcs_for_current_map()`；在 link/load 重建路徑的 `_rebuild_monsters_for_current_map()` 之後（約第 219 行）也新增一行 `_rebuild_npcs_for_current_map()`。

- [ ] **Step 5: 移除踩格觸發、改用 bump handler**

在 `_on_entered_cell` 內刪掉：

```gdscript
	if _try_quest_giver(local):
		return
```

把舊的 `_try_quest_giver(pos)` 整個函式（約第 363-375 行）**刪除**，改成 bump handler：

```gdscript
func _on_player_bumped(cell: Vector2i) -> void:
	if _dialogue_overlay.is_open() or _vendor_overlay.is_open():
		return
	var occ := _world_grid.occupant_at(cell)
	if String(occ.get("kind", "")) != "questgiver":
		return
	var data := DialogueCatalog.load_dialogue(String(occ["dialogue"]))
	if data == null:
		GameState.message_log.push("（對話 %s 遺失）" % occ["dialogue"])
		return
	_scene_once = false
	_player.set_enabled(false)
	_dialogue_overlay.open(DialogueRunner.new(data, GameState))
```

- [ ] **Step 6: 跑全套測試**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全綠（≥ baseline 978 + 新增測試），無 `_try_quest_giver` 殘留參考造成的 parse error。

- [ ] **Step 7: 開機 smoke**

Run: `./run.sh --headless`
Expected: 乾淨啟動、無 script error、自行退出（exit 0）。

- [ ] **Step 8: Commit**

```bash
git add presentation/world/main.gd
git commit -m "feat(npc): main 接 NpcLayer 重建 + bump→對話，移除踩格觸發" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7：quest_lint — questgiver 擺位規則

**Files:**
- Modify: `tools/quest_lint.gd`
- Test: `tests/content/test_quest_lint.gd`

**Interfaces:**
- Produces: `QuestLint.questgiver_placement_errors(map_id: String, map: MapData) -> Array`（回 error 字串）；`run()` 對所有 `content/maps` 套用。

- [ ] **Step 1: 寫失敗測試**

在 `tests/content/test_quest_lint.gd` 末端新增：

```gdscript
func _qg_lint_map(qg_pos: Vector2i, entry_pos: Vector2i, walls: Array = []) -> MapData:
	var m := MapData.new()
	m.map_id = "t"
	m.width = 5
	m.height = 5
	var t := PackedInt32Array()
	t.resize(25)   # 全 0 = FLOOR
	for w in walls:
		t[w.y * 5 + w.x] = MapData.TileType.WALL
	m.tiles = t
	m.entries = {"e": {"pos": entry_pos, "facing": 0}}
	m.quest_givers = [{"pos": qg_pos, "dialogue": "q", "sprite": ""}]
	return m

func test_questgiver_on_entry_is_error():
	var m := _qg_lint_map(Vector2i(2, 2), Vector2i(2, 2))
	assert_false(QuestLint.questgiver_placement_errors("t", m).is_empty(), "壓在入口格 → error")

func test_questgiver_surrounded_by_walls_is_error():
	var m := _qg_lint_map(Vector2i(2, 2), Vector2i(0, 0),
		[Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)])
	assert_false(QuestLint.questgiver_placement_errors("t", m).is_empty(), "四鄰皆牆 → error")

func test_valid_questgiver_placement_no_error():
	var m := _qg_lint_map(Vector2i(2, 2), Vector2i(0, 0))
	assert_eq(QuestLint.questgiver_placement_errors("t", m), [], "開放地板、非入口 → 無 error")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_quest_lint.gd -gexit`
Expected: FAIL（`questgiver_placement_errors` 未定義）

- [ ] **Step 3: 寫最小實作**

在 `tools/quest_lint.gd` 的 `run()` 內 `return` 前新增一行 `_check_questgiver_placement(errors)`，並新增以下兩個函式：

```gdscript
static func _check_questgiver_placement(errors: Array) -> void:
	for mid in _json_ids(MAPS_DIR):
		var map = MapImporter.parse(FileAccess.get_file_as_string("%s/%s.json" % [MAPS_DIR, mid]))
		if map == null:
			continue
		for e in questgiver_placement_errors(mid, map):
			errors.append(e)

# 任務 NPC 擺位規則（改實心擋路後）：(1) 不可壓在地圖入口格（否則玩家生成在實心 NPC 上→卡死），
# (2) 至少一個相鄰格可走（否則撞不到、永遠談不了）。回該圖的 error 字串陣列。
static func questgiver_placement_errors(map_id: String, map: MapData) -> Array:
	var errs: Array = []
	var entry_cells := {}
	for name in map.entries:
		entry_cells[map.entries[name]["pos"]] = true
	for q in map.quest_givers:
		var pos: Vector2i = q["pos"]
		if entry_cells.has(pos):
			errs.append("[map] %s questgiver@%s 壓在入口格（玩家會生成在實心 NPC 上）" % [map_id, pos])
		var has_adj := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = pos + d
			if n.x >= 0 and n.x < map.width and n.y >= 0 and n.y < map.height and map.get_tile(n) != MapData.TileType.WALL:
				has_adj = true
				break
		if not has_adj:
			errs.append("[map] %s questgiver@%s 四鄰皆牆（撞不到、無法對話）" % [map_id, pos])
	return errs
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_quest_lint.gd -gexit`
Expected: PASS（新 3 筆 + 既有 `test_quest_content_has_no_lint_errors` 仍 0 error → 確認現有地圖擺位合法）

- [ ] **Step 5: Commit**

```bash
git add tools/quest_lint.gd tests/content/test_quest_lint.gd
git commit -m "feat(lint): questgiver 擺位驗證（不壓入口格、需有相鄰可走格）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8：內容 — 4 張地圖 questgiver 補 `sprite`

**Files:**
- Modify: `content/maps/town_oak.json`、`content/maps/wild_nw.json`、`content/maps/wild_ne.json`、`content/maps/int_oak_smithy.json`

無新測試；gate＝lint 0 error + 全套綠。

- [ ] **Step 1: 替每個 questgiver entity 加 `sprite`**

各 questgiver 的 entity 物件加一個 `"sprite": "<id>"` 欄（id 可任意命名；目前 `NpcSpriteCatalog` 空 → 一律藍灰 placeholder，真圖之後委派時填進 catalog）。對照：

- `town_oak.json`：`qg_oak_guard`→`"oak_guard"`、`qg_margo`→`"margo"`、`qg_oak_lord`→`"oak_lord"`、`qg_oak_taxman`→`"oak_taxman"`
- `wild_nw.json`：`qg_nw_messenger`→`"nw_messenger"`
- `wild_ne.json`：`qg_ne_scout`→`"ne_scout"`
- `int_oak_smithy.json`：`qg_dorn`→`"oak_dorn"`

例（town_oak 守衛）：

```json
{"type": "questgiver", "pos": [3, 7], "dialogue": "qg_oak_guard", "sprite": "oak_guard"}
```

- [ ] **Step 2: 跑 lint + 全套測試**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全綠；`test_quest_content_has_no_lint_errors` 0 error（確認 4 張圖 questgiver 擺位皆合法）。

- [ ] **Step 3: Commit**

```bash
git add content/maps/town_oak.json content/maps/wild_nw.json content/maps/wild_ne.json content/maps/int_oak_smithy.json
git commit -m "content(npc): 橡鎮/野外 questgiver 補 sprite id（世界立繪）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9：對話視窗改羊皮紙 70/30

**Files:**
- Create: `content/ui/parchment_dialogue.png`
- Modify: `presentation/ui/dialogue_overlay.gd`
- Test: `tests/presentation/test_dialogue_overlay.gd`

**Interfaces:**
- 沿用既有成員名 `_image_rect` / `_text_label` / `_choice_box`（既有測試依賴），新增 `_parchment_rect`。`open/close/_render/_resolve_image/_unhandled_input` 不變。

- [ ] **Step 1: 生羊皮紙貼圖並匯入**

Run: `godot --headless --path . --script res://tools/gen_parchment.gd -- 1536 1024 res://content/ui/parchment_dialogue.png`
Then: `godot --headless --path . --import`
Expected: `content/ui/parchment_dialogue.png` 生成且被 Godot 匯入（`.import` 產生）。

- [ ] **Step 2: 寫失敗測試**

在 `tests/presentation/test_dialogue_overlay.gd` 末端新增：

```gdscript
func test_parchment_is_near_full_screen():
	var ov := _overlay()
	assert_lt(ov._parchment_rect.anchor_left, 0.06, "羊皮紙近滿版（左邊很小）")
	assert_gt(ov._parchment_rect.anchor_right, 0.94, "羊皮紙近滿版（右邊很大）")

func test_image_occupies_top_region():
	var ov := _overlay()
	assert_lt(ov._image_rect.anchor_top, 0.15, "情境圖貼近頂部")
	assert_almost_eq(ov._image_rect.anchor_bottom, 0.66, 0.03, "情境圖底約在 ~66%（上 ~70%）")

func test_text_box_in_bottom_region():
	var ov := _overlay()
	# 對話框是 _text_label 的父鏈最外層 Control；用其全域 anchor 反推：文字落在下方 ~30%
	assert_gt(ov._text_label.get_parent().get_parent().anchor_top, 0.6, "對話文字落在下半部")
```

> 註：`_text_label` 在 VBox 內、VBox 在對話框 Control 內，故 `get_parent().get_parent()` 取到對話框 Control。若實作的節點層級不同，調整成取對話框 Control 後斷言其 `anchor_top > 0.6`。

- [ ] **Step 3: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_dialogue_overlay.gd -gexit`
Expected: FAIL（`_parchment_rect` 未定義 / 版面 anchor 不符）

- [ ] **Step 4: 改版 `_ready`**

在 `presentation/ui/dialogue_overlay.gd` 成員區（`var _image_rect: TextureRect` 旁）新增：

```gdscript
var _parchment_rect: TextureRect
const PARCHMENT_PATH := "res://content/ui/parchment_dialogue.png"
```

把 `_ready()` 內「建 `_image_rect`（FULL_RECT）+ 底部 Panel box」那段（約第 22-43 行）整段換成：

```gdscript
	# 近滿版羊皮紙底（四周留 ~4% 邊）。
	_parchment_rect = TextureRect.new()
	if ResourceLoader.exists(PARCHMENT_PATH):
		_parchment_rect.texture = load(PARCHMENT_PATH)
	_parchment_rect.anchor_left = 0.04
	_parchment_rect.anchor_right = 0.96
	_parchment_rect.anchor_top = 0.04
	_parchment_rect.anchor_bottom = 0.96
	_parchment_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_parchment_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_parchment_rect)

	# 上 ~70%：情境圖（說話者表情或對話場景）。
	_image_rect = TextureRect.new()
	_image_rect.anchor_left = 0.09
	_image_rect.anchor_right = 0.91
	_image_rect.anchor_top = 0.09
	_image_rect.anchor_bottom = 0.66
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_image_rect)

	# 下 ~30%：對話框（文字 + 數字鍵選項）。
	var box := Control.new()
	box.anchor_left = 0.09
	box.anchor_right = 0.91
	box.anchor_top = 0.66
	box.anchor_bottom = 0.92
	add_child(box)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	# 羊皮紙是淺米色，預設白字看不清 → 用 Theme 讓 vb 底下所有 Label（含 _render 動態建的選項/提示）統一深棕字。
	var parchment_theme := Theme.new()
	parchment_theme.set_color("font_color", "Label", Color(0.18, 0.12, 0.06))
	vb.theme = parchment_theme
	box.add_child(vb)
```

`_ready()` 其餘（`_text_label`/`_choice_box` 建在 `vb` 下、`set_process_unhandled_input(false)`）保持不變——確認它們仍 `vb.add_child(...)`。深棕字色由 `vb.theme` 沿 Control 樹向下繼承，故 `_render` 動態建的選項 Label 也自動套用，`_render` 不需改。

- [ ] **Step 5: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_dialogue_overlay.gd -gexit`
Expected: PASS（新版面 3 筆 + 既有 text/choices/texture 測試仍綠）

- [ ] **Step 6: 全套測試 + 開機 smoke**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Then: `./run.sh --headless`
Expected: 全綠 + 乾淨啟動退出。

- [ ] **Step 7: Commit**

```bash
git add content/ui/parchment_dialogue.png content/ui/parchment_dialogue.png.import presentation/ui/dialogue_overlay.gd tests/presentation/test_dialogue_overlay.gd
git commit -m "feat(ui): 對話視窗改近滿版羊皮紙（上 70% 情境圖／下 30% 對話）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 最終人工視覺 gate（`./run.sh`）

實作完成後，人工跑 `./run.sh` 確認：

1. 進橡鎮看到 **4 個 NPC 立繪**站在格上（目前藍灰 placeholder，有輕微 idle 晃動）。
2. 面向某 NPC **按前進撞上去** → 開**羊皮紙對話視窗**（上情境圖、下對話、數字鍵選項）。
3. **撞牆**無事（不誤開對話）；NPC **擋路**走不過去。
4. 野外信使（wild_nw）／斥候（wild_ne）／鐵匠多恩（int_oak_smithy）同樣可撞談。
5. 既有 scene/vendor/chest 的踩格觸發行為不變。
