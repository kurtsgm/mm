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

func test_cluster_members_feet_on_floor():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0), "g")])   # 3 隻（縮放叢）
	var s: Sprite3D = l._sprites["u1"][1]["node"]
	var wh := s.texture.get_height() * s.pixel_size   # 實際渲染身高
	assert_almost_eq(s.position.y - wh / 2.0, 0.0, 0.0001, "縮放後仍腳貼地")

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

func test_cluster_offsets_grid_centered():
	for n in [4, 5, 6, 7]:
		var offs := MonsterLayer.cluster_offsets(n, 0.5)
		assert_eq(offs.size(), n, "n=%d 回傳剛好 n 個" % n)
		var sum := Vector3.ZERO
		for o in offs:
			sum += o
		assert_almost_eq(sum.x, 0.0, 0.0001, "n=%d x 質心置中" % n)
		assert_almost_eq(sum.z, 0.0, 0.0001, "n=%d z 質心置中" % n)

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
