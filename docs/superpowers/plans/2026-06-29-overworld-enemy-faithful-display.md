# 大地圖怪忠實呈現種類與數量 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 大地圖一格的遊蕩敵人，視覺上畫出該遭遇組「實際的種類與數量」——group 有幾隻、各是什麼怪，就畫幾個對應種類的 billboard 排成一叢。

**Architecture:** 只改呈現層 `presentation/world/monster_layer.gd`：把「一格 = 一個 Sprite3D」改成「一格 = 一叢（N 個 Sprite3D，每隻對應 group 裡的一隻 def）」。新增純函式 `cluster_offsets` 決定叢內擺位。邏輯層（`overworld_monsters.gd`）、`main.gd`、`bestiary.gd`、存檔格式完全不動——一格仍是一個邏輯 actor（一個 uid／cell／group／狀態）。

**Tech Stack:** Godot 4.7、GDScript、GUT 測試框架（`res://addons/gut/gut_cmdln.gd`，讀 `.gutconfig.json`）。

## Global Constraints

- **不需向後相容**：改內部結構/測試直接改成最乾淨的樣子，一併更新所有呼叫端與既有測試；不寫相容層。
- **版面/尺寸用比例**：叢的擺幅 `spread` 以 `GridGeometry.CELL_SIZE`（= 2.0）比例算，不寫死世界值/像素。
- **溝通語言**：對使用者的說明一律繁體中文（程式碼/commit 訊息維持既有慣例）。
- **Sub-agent 模型**：dispatch sub-agent 一律繼承 parent model，不得指定其他模型。
- **美術 fallback**：未註冊貼圖的怪沿用既有紅方塊 placeholder + 微幅晃動 fallback，不另畫圖。

**測試指令**
- 全套：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`（自動讀 `.gutconfig.json`）
- 單檔：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_monster_layer.gd -gexit`

**檔案結構（本計畫只動兩個檔）**
- Modify：`presentation/world/monster_layer.gd` — 大地圖怪 billboard 層（核心改動）。
- Modify：`tests/presentation/world/test_monster_layer.gd` — 對應測試（新增 + 改寫）。

---

### Task 1: 純函式 `cluster_offsets`（叢內擺位）

新增一個純（static、無副作用、確定性）函式：給定怪數 `n` 與擺幅半徑 `spread`，回傳 `n` 個 XZ 平面上的位移（`Vector3`，y=0）。此 task 只新增函式與其測試，**不改既有渲染流程**，既有測試維持綠燈。

**Files:**
- Modify: `presentation/world/monster_layer.gd`（新增 static func，置於既有 `frame_index` 之後）
- Test: `tests/presentation/world/test_monster_layer.gd`（新增 4 個測試）

**Interfaces:**
- Produces: `static func cluster_offsets(n: int, spread: float) -> Array[Vector3]`
  - `n <= 1` → `[Vector3.ZERO]`
  - 整體置中（所有 offset 之和 ≈ `Vector3.ZERO`）、確定性（同輸入同輸出）
  - `n == 3` 時各 offset 的 x、z 分量皆落在 `[-spread, spread]`

- [ ] **Step 1: 寫失敗測試**

把以下測試加到 `tests/presentation/world/test_monster_layer.gd`（檔尾即可）：

```gdscript
# ---- cluster_offsets：叢內擺位 ----
func test_cluster_offsets_single_centered():
	var offs := MonsterLayer.cluster_offsets(1, 0.5)
	assert_eq(offs.size(), 1)
	assert_true(offs[0].is_equal_approx(Vector3.ZERO), "單隻置中")

func test_cluster_offsets_returns_exactly_n():
	assert_eq(MonsterLayer.cluster_offsets(2, 0.5).size(), 2)
	assert_eq(MonsterLayer.cluster_offsets(3, 0.5).size(), 3)
	assert_eq(MonsterLayer.cluster_offsets(5, 0.5).size(), 5)

func test_cluster_offsets_three_distinct_centered_in_bounds():
	var spread := 0.5
	var offs := MonsterLayer.cluster_offsets(3, spread)
	assert_false(offs[0].is_equal_approx(offs[1]), "三隻互不重疊")
	assert_false(offs[1].is_equal_approx(offs[2]))
	assert_false(offs[0].is_equal_approx(offs[2]))
	for o in offs:
		assert_true(absf(o.x) <= spread + 0.0001, "x 落在 spread 內")
		assert_true(absf(o.z) <= spread + 0.0001, "z 落在 spread 內")
	var sum := Vector3.ZERO
	for o in offs:
		sum += o
	assert_almost_eq(sum.x, 0.0, 0.0001, "x 對稱置中")
	assert_almost_eq(sum.z, 0.0, 0.0001, "z 對稱置中")

func test_cluster_offsets_deterministic():
	assert_eq(str(MonsterLayer.cluster_offsets(3, 0.5)), str(MonsterLayer.cluster_offsets(3, 0.5)), "同輸入同輸出")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_monster_layer.gd -gexit`
Expected: FAIL（`cluster_offsets` 尚未定義 / 找不到方法）

- [ ] **Step 3: 實作純函式**

在 `presentation/world/monster_layer.gd` 的 `frame_index` static 函式之後，加入：

```gdscript
# 純函式：n 隻怪在格內的叢擺位（XZ 平面 offset，y=0）。spread=擺幅半徑（世界單位）。
# 整體置中（centroid≈0）、確定性。n<=1 置中；2 並排；3 三角（前後分層）；>=4 每列至多 3 的置中網格。
static func cluster_offsets(n: int, spread: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if n <= 1:
		out.append(Vector3.ZERO)
		return out
	if n == 2:
		out.append(Vector3(-spread, 0.0, 0.0))
		out.append(Vector3(spread, 0.0, 0.0))
		return out
	if n == 3:
		out.append(Vector3(0.0, 0.0, -spread * 0.8))    # 後置中
		out.append(Vector3(-spread, 0.0, spread * 0.4))  # 前左
		out.append(Vector3(spread, 0.0, spread * 0.4))   # 前右
		return out
	var per_row := 3
	var rows := int(ceil(float(n) / float(per_row)))
	for r in rows:
		var in_row: int = min(per_row, n - r * per_row)
		for c in in_row:
			var x := (float(c) - float(in_row - 1) / 2.0) * spread
			var z := (float(r) - float(rows - 1) / 2.0) * spread
			out.append(Vector3(x, 0.0, z))
	return out
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_monster_layer.gd -gexit`
Expected: PASS（含既有 monster_layer 測試全綠 + 4 個新 cluster_offsets 測試）

- [ ] **Step 5: Commit**

```bash
git add presentation/world/monster_layer.gd tests/presentation/world/test_monster_layer.gd
git commit -m "feat(world): cluster_offsets 純函式（叢內擺位）"
```

---

### Task 2: 大地圖怪一格畫成一叢 N 個 sprite（每隻對應 group 的 def）

把 `MonsterLayer` 從「uid → 單一 Sprite3D」重構為「uid → member 陣列」，每個 member 對應 group 裡的一隻怪、用該怪種類的貼圖、擺在 `cluster_offsets` 給的位置。整叢一起動畫與移動。改寫受影響的既有測試到新結構，並新增「每隻一個 sprite / 種類正確 / 數量正確 / 叢置中」的行為測試。

**Files:**
- Modify: `presentation/world/monster_layer.gd`（重構為 member 陣列 + 用 `cluster_offsets` + 逐隻取 def 貼圖 + n≥2 縮小）
- Test: `tests/presentation/world/test_monster_layer.gd`（改寫結構相關測試；保留純函式測試與 Task 1 的 cluster_offsets 測試）

**Interfaces:**
- Consumes:
  - `Bestiary.group_defs_for(group: String) -> Array[MonsterDef]`（每隻 `def.id: String`）
  - `MonsterSpriteCatalog.textures_for(monster_id: String) -> {idle, idle2, attack, hurt}`（各為 `Texture2D|null`）
  - `cluster_offsets(n, spread)`（Task 1）
  - `GridGeometry.CELL_SIZE`（= 2.0）、`GridGeometry.cell_to_world(cell)`
  - `CombatStage.DISPLAY_HEIGHT`、`CombatStage.pixel_size_for(tex, h)`
- Produces（公開 API 簽章不變；內部結構改變）：
  - `rebuild(monsters: Array) -> void`、`apply_moves(monsters: Array) -> void`（input 仍為 `[{uid, group, cell, state}, ...]`）
  - 內部 `_sprites: Dictionary`：`uid -> Array[member]`，member = `{node: Sprite3D, a: Texture2D, b: Texture2D|null, phase: float, cur: int, offset: Vector3, scale: float}`
  - 新常數：`CLUSTER_SPREAD_RATIO := 0.28`、`CLUSTER_SCALE := 0.82`
  - 內部 `_update_member(member: Dictionary, t: float) -> void`（取代舊 `_update_frame(uid, t)`）

- [ ] **Step 1: 改寫測試到新結構（失敗測試）**

把 `tests/presentation/world/test_monster_layer.gd` **整檔替換**為以下內容（保留 Task 1 的 cluster_offsets 測試與純函式測試；結構測試改用 member 陣列）：

```gdscript
extends GutTest

func _layer() -> MonsterLayer:
	var l := MonsterLayer.new()
	add_child_autofree(l)
	return l

func _live(uid: String, cell: Vector2i, group: String) -> Dictionary:
	return {"uid": uid, "group": group, "cell": cell, "state": 0}

# ---- rebuild：每隻怪一個 sprite（種類 + 數量忠實呈現）----
func test_rebuild_tracks_one_entry_per_uid():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(1, 1), "o"), _live("u2", Vector2i(2, 3), "o")])
	assert_eq(l._sprites.size(), 2, "兩個 uid 兩筆")

func test_rebuild_one_sprite_per_monster_in_group():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(1, 1), "g")])   # "g" = goblin x3
	assert_eq(l._sprites["u1"].size(), 3, "group 'g'=3 隻 → 3 個 member")
	assert_eq(l.get_child_count(), 3, "3 個 Sprite3D 加進場景")

func test_single_monster_group_centered_full_size():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0), "o")])   # "o" = ogre x1
	assert_eq(l._sprites["u1"].size(), 1)
	var member: Dictionary = l._sprites["u1"][0]
	assert_true(member["offset"].is_equal_approx(Vector3.ZERO), "單隻置中（offset 0）")
	var s: Sprite3D = member["node"]
	assert_almost_eq(s.pixel_size, CombatStage.pixel_size_for(s.texture, CombatStage.DISPLAY_HEIGHT), 0.0001, "單隻維持原大小")

func test_cluster_members_scaled_down_when_multiple():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0), "g")])   # 3 隻
	var s: Sprite3D = l._sprites["u1"][0]["node"]
	var full := CombatStage.pixel_size_for(s.texture, CombatStage.DISPLAY_HEIGHT)
	assert_almost_eq(s.pixel_size, full * MonsterLayer.CLUSTER_SCALE, 0.0001, "n>=2 → 縮小 CLUSTER_SCALE")

func test_cluster_centered_on_cell():
	var l := _layer()
	var cell := Vector2i(2, 3)
	l.rebuild([_live("u1", cell, "g")])   # 3 隻
	var w := GridGeometry.cell_to_world(cell)
	var sum := Vector3.ZERO
	for member in l._sprites["u1"]:
		sum += member["node"].position
	var centroid := sum / float(l._sprites["u1"].size())
	assert_almost_eq(centroid.x, w.x, 0.0001, "叢以格中心置中（x）")
	assert_almost_eq(centroid.z, w.z, 0.0001, "叢以格中心置中（z）")

func test_rebuild_places_feet_on_floor():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(1, 1), "o")])   # 單隻 offset 0
	var s: Sprite3D = l._sprites["u1"][0]["node"]
	assert_almost_eq(s.position.y, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0001, "腳貼地")
	var w := GridGeometry.cell_to_world(Vector2i(1, 1))
	assert_almost_eq(s.position.x, w.x, 0.0001)
	assert_almost_eq(s.position.z, w.z, 0.0001)

func test_rebuild_uses_billboard():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0), "o")])
	var s: Sprite3D = l._sprites["u1"][0]["node"]
	assert_eq(s.billboard, BaseMaterial3D.BILLBOARD_ENABLED)

func test_rebuild_clears_previous():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0), "o"), _live("u2", Vector2i(1, 0), "o")])
	l.rebuild([_live("u3", Vector2i(2, 0), "o")])
	assert_eq(l._sprites.size(), 1)
	assert_true(l._sprites.has("u3"))
	assert_eq(l.get_child_count(), 1, "舊 sprite 已釋放")

func test_apply_moves_no_crash_and_keeps_members():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0), "g")])   # 3 隻
	l.apply_moves([_live("u1", Vector2i(1, 0), "g")])   # 觸發補間，不 crash
	assert_eq(l._sprites["u1"].size(), 3)

func test_goblin_members_use_idle_texture():
	var l := _layer()
	l.rebuild([_live("g1", Vector2i(0, 0), "g")])
	var idle: Texture2D = MonsterSpriteCatalog.textures_for("goblin")["idle"]
	for member in l._sprites["g1"]:
		assert_eq(member["node"].texture, idle, "每隻哥布林都用 goblin idle 真圖")

func test_unknown_group_uses_non_null_placeholder():
	var l := _layer()
	l.rebuild([_live("x1", Vector2i(0, 0), "no_such_group")])
	assert_eq(l._sprites["x1"].size(), 1, "未知 group → 單一 placeholder")
	assert_not_null(l._sprites["x1"][0]["node"].texture, "placeholder 非 null")

func test_rebuild_assigns_distinct_incrementing_phases():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0), "g"), _live("u2", Vector2i(2, 0), "o")])
	var m1: Array = l._sprites["u1"]   # goblin x3
	assert_eq(m1.size(), 3)
	assert_almost_eq(m1[0]["phase"], 0.0, 0.0001, "第 0 隻相位 0")
	assert_almost_eq(m1[1]["phase"], MonsterLayer.PHASE_SPREAD, 0.0001)
	assert_almost_eq(m1[2]["phase"], 2.0 * MonsterLayer.PHASE_SPREAD, 0.0001)
	var m2: Array = l._sprites["u2"]   # ogre x1，seed 接續到 3
	assert_almost_eq(m2[0]["phase"], 3.0 * MonsterLayer.PHASE_SPREAD, 0.0001, "跨 uid 相位接續遞增")

func test_rebuild_enables_processing_when_monsters_present():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0), "o")])
	assert_true(l.is_processing(), "有怪 → idle 動畫常駐開啟")

func test_rebuild_empty_disables_processing():
	var l := _layer()
	l.rebuild([])
	assert_false(l.is_processing(), "無怪 → 關閉 process")

func test_process_applies_bounded_horizontal_only_sway():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0), "no_such_group")])   # 無 idle2 → 晃動 fallback
	l._process(0.016)
	var s: Sprite3D = l._sprites["u1"][0]["node"]
	var max_px: float = MonsterLayer.SWAY_WORLD / s.pixel_size
	assert_lt(absf(s.offset.x), max_px + 0.0001, "晃動不超過世界振幅換算")
	assert_almost_eq(s.offset.y, 0.0, 0.0001, "只左右、不上下")

# ---- idle 兩幀假動畫 / 晃動 fallback（member 層級）----
func test_update_member_swaps_texture_when_second_frame_present():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0), "o")])   # ogre，placeholder，b=null
	var member: Dictionary = l._sprites["u1"][0]
	var s: Sprite3D = member["node"]
	var tex_a = member["a"]
	var tex_b := ImageTexture.create_from_image(Image.create(32, 48, false, Image.FORMAT_RGBA8))
	member["b"] = tex_b
	member["cur"] = 0
	member["phase"] = 0.0
	l._update_member(member, 0.4)   # idx=1 → 切到 b
	assert_eq(s.texture, tex_b, "有第二幀 → t=period 切到 frame B")
	l._update_member(member, 0.8)   # idx=0 → 切回 a
	assert_eq(s.texture, tex_a, "回 frame A")

func test_update_member_falls_back_to_sway_without_second_frame():
	var l := _layer()
	l.rebuild([_live("x1", Vector2i(0, 0), "no_such_group")])   # placeholder, b=null
	var member: Dictionary = l._sprites["x1"][0]
	var s: Sprite3D = member["node"]
	member["phase"] = 0.0
	l._update_member(member, 0.45)
	assert_almost_eq(s.offset.y, 0.0, 0.0001, "fallback 晃動只左右")
	var max_px: float = MonsterLayer.SWAY_WORLD / s.pixel_size
	assert_lt(absf(s.offset.x), max_px + 0.0001)

# ---- cluster_offsets：叢內擺位（Task 1）----
func test_cluster_offsets_single_centered():
	var offs := MonsterLayer.cluster_offsets(1, 0.5)
	assert_eq(offs.size(), 1)
	assert_true(offs[0].is_equal_approx(Vector3.ZERO), "單隻置中")

func test_cluster_offsets_returns_exactly_n():
	assert_eq(MonsterLayer.cluster_offsets(2, 0.5).size(), 2)
	assert_eq(MonsterLayer.cluster_offsets(3, 0.5).size(), 3)
	assert_eq(MonsterLayer.cluster_offsets(5, 0.5).size(), 5)

func test_cluster_offsets_three_distinct_centered_in_bounds():
	var spread := 0.5
	var offs := MonsterLayer.cluster_offsets(3, spread)
	assert_false(offs[0].is_equal_approx(offs[1]), "三隻互不重疊")
	assert_false(offs[1].is_equal_approx(offs[2]))
	assert_false(offs[0].is_equal_approx(offs[2]))
	for o in offs:
		assert_true(absf(o.x) <= spread + 0.0001, "x 落在 spread 內")
		assert_true(absf(o.z) <= spread + 0.0001, "z 落在 spread 內")
	var sum := Vector3.ZERO
	for o in offs:
		sum += o
	assert_almost_eq(sum.x, 0.0, 0.0001, "x 對稱置中")
	assert_almost_eq(sum.z, 0.0, 0.0001, "z 對稱置中")

func test_cluster_offsets_deterministic():
	assert_eq(str(MonsterLayer.cluster_offsets(3, 0.5)), str(MonsterLayer.cluster_offsets(3, 0.5)), "同輸入同輸出")

# ---- idle 左右微幅晃動（純函式，沿用）----
func test_sway_offset_px_world_amplitude_independent_of_pixel_size():
	var period := 1.8
	var t := period / 4.0
	var off_a := MonsterLayer.sway_offset_px(t, 0.0, 0.04, period, 0.01)
	var off_b := MonsterLayer.sway_offset_px(t, 0.0, 0.04, period, 0.02)
	assert_almost_eq(off_a * 0.01, 0.04, 0.0001, "world 振幅 = offset_px × pixel_size（峰值）")
	assert_almost_eq(off_b * 0.02, 0.04, 0.0001, "不同 pixel_size 同 world 振幅")
	assert_almost_eq(off_a, off_b * 2.0, 0.0001, "pixel_size 減半 → offset_px 加倍")

func test_sway_offset_px_zero_at_start():
	assert_almost_eq(MonsterLayer.sway_offset_px(0.0, 0.0, 0.04, 1.8, 0.01), 0.0, 0.0001, "t=0,phase=0 → sin(0)=0 無位移")

func test_sway_offset_px_phase_shifts_waveform():
	var off := MonsterLayer.sway_offset_px(0.0, PI / 2.0, 0.04, 1.8, 0.01)
	assert_almost_eq(off, 0.04 / 0.01, 0.0001, "phase=PI/2 → t=0 即峰值")

func test_sway_offset_px_guards_zero_pixel_size():
	var off := MonsterLayer.sway_offset_px(0.45, 0.0, 0.04, 1.8, 0.0)
	assert_true(is_finite(off), "pixel_size=0 → max guard，不 inf/nan")

# ---- idle 兩幀假動畫（純函式，沿用）----
func test_frame_index_swaps_each_period():
	assert_eq(MonsterLayer.frame_index(0.0, 0.0, 0.4), 0, "t=0 → 第 0 幀")
	assert_eq(MonsterLayer.frame_index(0.4, 0.0, 0.4), 1, "t=period → 第 1 幀")
	assert_eq(MonsterLayer.frame_index(0.8, 0.0, 0.4), 0, "t=2·period → 回第 0 幀")

func test_frame_index_phase_offsets_beat():
	assert_eq(MonsterLayer.frame_index(0.0, 1.0, 0.4), 1, "beat_offset=1 → 提前一拍，t=0 即第 1 幀")

func test_frame_index_guards_zero_period():
	var idx := MonsterLayer.frame_index(0.5, 0.0, 0.0)
	assert_true(idx == 0 or idx == 1, "period=0 → max guard，不崩")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_monster_layer.gd -gexit`
Expected: FAIL（舊 `monster_layer.gd` 把 `_sprites[uid]` 當單一 Sprite3D，新測試把它當 Array、且查 `member["node"]`/`CLUSTER_SCALE`/`_update_member` 皆不存在）

- [ ] **Step 3: 重構 `monster_layer.gd`**

把 `presentation/world/monster_layer.gd` **整檔替換**為：

```gdscript
class_name MonsterLayer
extends Node3D

# 大地圖會走動的怪 billboard 層。一格的遭遇組「實際的種類與數量」忠實畫出：
# group 有幾隻、各是什麼怪，就畫幾個對應種類的 Sprite3D 排成一叢（cluster）。
# 跟著切地圖由 main.gd rebuild。腳貼地與尺寸共用 CombatStage 的常數/static。
# idle 生命感：有第二幀(idle2)的怪走「兩幀輪播」假動畫；沒有的退回「微幅左右晃動」。
const MOVE_TIME := 0.18      # 移動補間時長（對齊玩家步速 feel）
const SWAY_WORLD := 0.04     # idle 左右晃動世界振幅
const SWAY_PERIOD := 1.8     # idle 晃動週期（秒）
const PHASE_SPREAD := 1.7    # 每隻相位間隔（弧度）→ 一群怪不同手同腳
const FRAME_PERIOD := 0.4    # idle 兩幀假動畫單幀顯示時長（秒）
const CLUSTER_SPREAD_RATIO := 0.28   # 叢擺幅半徑 / GridGeometry.CELL_SIZE（格距比例，不寫死世界值/像素）
const CLUSTER_SCALE := 0.82  # n>=2 時叢內 sprite 縮小倍率（避免擠出格外；n=1 維持原大小）

# uid -> Array[member]；member = {node:Sprite3D, a:Texture2D, b:Texture2D|null, phase:float, cur:int, offset:Vector3, scale:float}
var _sprites: Dictionary = {}

# 純函式：idle 左右晃動的 billboard offset.x（像素，本地平面）。
# 以 SWAY_WORLD 世界振幅 / pixel_size 換算成像素 → 任何貼圖尺寸都呈現相同世界振幅。
static func sway_offset_px(t: float, phase: float, sway_world: float, period: float, pixel_size: float) -> float:
	return (sway_world / max(pixel_size, 0.0001)) * sin(t * TAU / period + phase)

# 純函式：兩幀假動畫的幀索引（0/1）。每 period 秒切換；beat_offset（拍）每怪錯開避免同步。
static func frame_index(t: float, beat_offset: float, period: float) -> int:
	return int(floor(t / max(period, 0.0001) + beat_offset)) % 2

# 純函式：n 隻怪在格內的叢擺位（XZ 平面 offset，y=0）。spread=擺幅半徑（世界單位）。
# 整體置中（centroid≈0）、確定性。n<=1 置中；2 並排；3 三角（前後分層）；>=4 每列至多 3 的置中網格。
static func cluster_offsets(n: int, spread: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if n <= 1:
		out.append(Vector3.ZERO)
		return out
	if n == 2:
		out.append(Vector3(-spread, 0.0, 0.0))
		out.append(Vector3(spread, 0.0, 0.0))
		return out
	if n == 3:
		out.append(Vector3(0.0, 0.0, -spread * 0.8))    # 後置中
		out.append(Vector3(-spread, 0.0, spread * 0.4))  # 前左
		out.append(Vector3(spread, 0.0, spread * 0.4))   # 前右
		return out
	var per_row := 3
	var rows := int(ceil(float(n) / float(per_row)))
	for r in rows:
		var in_row: int = min(per_row, n - r * per_row)
		for c in in_row:
			var x := (float(c) - float(in_row - 1) / 2.0) * spread
			var z := (float(r) - float(rows - 1) / 2.0) * spread
			out.append(Vector3(x, 0.0, z))
	return out

func rebuild(monsters: Array) -> void:
	_clear()
	var phase_seed := 0
	for m in monsters:
		var members := _build_members(m["group"], m["cell"], phase_seed)
		_sprites[m["uid"]] = members
		phase_seed += members.size()
	set_process(not _sprites.is_empty())   # idle 動畫常駐（有怪才開）

# 依 group 的 defs（種類+數量）建該 uid 的所有 member sprite，加入場景並回傳 member 陣列。
func _build_members(group_key: String, cell: Vector2i, phase_seed: int) -> Array:
	var defs := Bestiary.group_defs_for(group_key)
	var n: int = defs.size()
	var members: Array = []
	if n == 0:
		# 未知 group → 單一紅方塊 placeholder（維持既有 fallback）
		members.append(_make_member(_placeholder(Color(0.8, 0.3, 0.3)), null, cell, Vector3.ZERO, 1.0, phase_seed))
		return members
	var spread := CLUSTER_SPREAD_RATIO * GridGeometry.CELL_SIZE
	var offsets := cluster_offsets(n, spread)
	var scale: float = CLUSTER_SCALE if n >= 2 else 1.0
	for i in n:
		var fr := _frames_for_def(defs[i].id)
		members.append(_make_member(fr["a"], fr["b"], cell, offsets[i], scale, phase_seed + i))
	return members

# 建單一 member（Sprite3D + 動畫資料），加入場景並回傳 member dict。
func _make_member(a: Texture2D, b, cell: Vector2i, offset: Vector3, scale: float, phase_seed: int) -> Dictionary:
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_apply_texture(s, a, scale)
	s.position = _world_pos(cell) + offset
	add_child(s)
	return {"node": s, "a": a, "b": b, "phase": phase_seed * PHASE_SPREAD, "cur": 0, "offset": offset, "scale": scale}

func apply_moves(monsters: Array) -> void:
	for m in monsters:
		var uid: String = m["uid"]
		if not _sprites.has(uid):
			continue
		var base := _world_pos(m["cell"])
		for member in _sprites[uid]:
			var s: Sprite3D = member["node"]
			var target: Vector3 = base + member["offset"]
			if s.position.is_equal_approx(target):
				continue
			var tw := create_tween()
			tw.tween_property(s, "position", target, MOVE_TIME)

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for uid in _sprites:
		for member in _sprites[uid]:
			if is_instance_valid(member["node"]):
				_update_member(member, t)

# 有第二幀（idle2）→ 兩幀輪播；否則 → 微幅左右晃動 fallback。兩者與 position 獨立，不擾移動補間。
func _update_member(member: Dictionary, t: float) -> void:
	var s: Sprite3D = member["node"]
	if member["b"] != null:
		var idx := frame_index(t, member["phase"] / TAU, FRAME_PERIOD)
		if idx != member["cur"]:
			_apply_texture(s, member["b"] if idx == 1 else member["a"], member["scale"])
			member["cur"] = idx
	else:
		s.offset = Vector2(sway_offset_px(t, member["phase"], SWAY_WORLD, SWAY_PERIOD, s.pixel_size), 0.0)

func _world_pos(cell: Vector2i) -> Vector3:
	return GridGeometry.cell_to_world(cell) + Vector3(0.0, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0)

# 某怪 id 的兩幀：idle(真圖/placeholder)=a、idle2=b（可 null → 退回晃動）。
func _frames_for_def(def_id: String) -> Dictionary:
	var ph := _placeholder(Color(0.8, 0.3, 0.3))
	var t = MonsterSpriteCatalog.textures_for(def_id)
	var a = t["idle"] if t["idle"] != null else ph
	return {"a": a, "b": t.get("idle2", null)}

# 設貼圖並依其高度正規化 pixel_size（換幀不變大小、腳貼地不變）；scale 為叢內縮小倍率。
func _apply_texture(s: Sprite3D, tex: Texture2D, scale: float) -> void:
	s.texture = tex
	s.pixel_size = CombatStage.pixel_size_for(tex, CombatStage.DISPLAY_HEIGHT) * scale

func _placeholder(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_sprites.clear()
	set_process(false)
```

- [ ] **Step 4: 跑單檔測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_monster_layer.gd -gexit`
Expected: PASS（全部 monster_layer 測試綠）

- [ ] **Step 5: 跑全套測試確認無回歸**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: PASS（全綠；本計畫只動呈現層 + 其測試，邏輯/存檔/戰鬥不受影響）

- [ ] **Step 6: Commit**

```bash
git add presentation/world/monster_layer.gd tests/presentation/world/test_monster_layer.gd
git commit -m "feat(world): 大地圖怪一格畫成一叢，忠實呈現種類與數量"
```

---

## 人工視覺 gate（非自動化）

實作完成後，跑 `./run.sh` 親眼確認：

- 走到有怪的格子前，大地圖上該格現在顯示「整組」的怪（如哥布林 3 隻成一叢、夢魘妖 2 隻），數量與踩下去的實戰一致。
- 一叢的怪各自呼吸/晃動、不同步；不會擠出格外或互相完全重疊。
- 怪追擊玩家時整叢一起平移、無殘影/錯位。

如覺得叢太擠或太鬆、縮太小：微調 `CLUSTER_SPREAD_RATIO`（擺幅）與 `CLUSTER_SCALE`（大小），重跑即可（純呈現參數，不影響測試結構）。

## Self-Review（已執行）

- **Spec coverage**：種類忠實（逐隻 `defs[i].id` 取貼圖，Task 2）、數量忠實（每隻一個 sprite + `cluster_offsets`，Task 1+2）、只動呈現層（邏輯/存檔/戰鬥不改，Task 2 介面註明）、混編組自動成立（逐隻取 def）、不設數量上限（`cluster_offsets` n>=4 多列）、叢內縮小（`CLUSTER_SCALE`）、不同步動畫（phase 遞增）、fallback（未知 group placeholder + 晃動）皆有對應 task/測試。
- **Placeholder scan**：無 TBD/TODO；每個 code step 皆為完整可貼上的程式碼。
- **Type consistency**：`_sprites` 全程為 `uid -> Array[member]`；member 鍵 `{node,a,b,phase,cur,offset,scale}` 在 `_make_member` 定義、在 `_update_member`/測試一致引用；`cluster_offsets(int,float)->Array[Vector3]`、`_update_member(Dictionary,float)`、`_apply_texture(Sprite3D,Texture2D,float)` 簽章前後一致。
