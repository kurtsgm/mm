extends GutTest

func _layer() -> MonsterLayer:
	var l := MonsterLayer.new()
	add_child_autofree(l)
	return l

func _live(uid: String, cell: Vector2i) -> Dictionary:
	return {"uid": uid, "group": "g", "cell": cell, "state": 0}

func test_rebuild_one_sprite_per_monster():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(1, 1)), _live("u2", Vector2i(2, 3))])
	assert_eq(l._sprites.size(), 2)

func test_rebuild_places_billboard_feet_on_floor():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(1, 1))])
	var s: Sprite3D = l._sprites["u1"]
	assert_almost_eq(s.position.y, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0001, "中心在地板上方 DISPLAY_HEIGHT/2（腳貼地）")
	var w := GridGeometry.cell_to_world(Vector2i(1, 1))
	assert_almost_eq(s.position.x, w.x, 0.0001)
	assert_almost_eq(s.position.z, w.z, 0.0001)

func test_rebuild_uses_billboard_and_normalized_size():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0))])
	var s: Sprite3D = l._sprites["u1"]
	assert_eq(s.billboard, BaseMaterial3D.BILLBOARD_ENABLED)
	assert_almost_eq(s.pixel_size, CombatStage.pixel_size_for(s.texture, CombatStage.DISPLAY_HEIGHT), 0.0001, "尺寸與戰鬥一致")

func test_rebuild_clears_previous():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0)), _live("u2", Vector2i(1, 0))])
	l.rebuild([_live("u3", Vector2i(2, 0))])
	assert_eq(l._sprites.size(), 1)
	assert_true(l._sprites.has("u3"))

func test_apply_moves_no_crash_and_keeps_count():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0))])
	l.apply_moves([_live("u1", Vector2i(1, 0))])   # 觸發補間，不 crash
	assert_eq(l._sprites.size(), 1)

func test_goblin_group_uses_idle_texture():
	var l := _layer()
	l.rebuild([{"uid": "g1", "group": "g", "cell": Vector2i(0, 0), "state": 0}])
	var s: Sprite3D = l._sprites["g1"]
	var idle: Texture2D = MonsterSpriteCatalog.textures_for("goblin")["idle"]
	assert_eq(s.texture, idle, "哥布林群組（g→goblin.tres，id=goblin）代表用 idle 真圖")

func test_unknown_group_uses_non_null_placeholder():
	var l := _layer()
	l.rebuild([{"uid": "x1", "group": "no_such_group", "cell": Vector2i(0, 0), "state": 0}])
	var s: Sprite3D = l._sprites["x1"]
	assert_not_null(s.texture, "未知群組（無真圖）→ placeholder 非 null，避免 runtime null texture")

# ---- idle 左右微幅晃動 ----
func test_sway_offset_px_world_amplitude_independent_of_pixel_size():
	# sin 峰值（t=period/4、phase=0 → t·TAU/period = PI/2）時 offset_px × pixel_size == sway_world。
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

func test_rebuild_assigns_distinct_per_monster_phase():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0)), _live("u2", Vector2i(1, 0))])
	assert_true(l._phase.has("u1") and l._phase.has("u2"))
	assert_almost_eq(l._phase["u1"], 0.0, 0.0001, "第 0 隻相位 0")
	assert_almost_eq(l._phase["u2"], MonsterLayer.PHASE_SPREAD, 0.0001, "第 1 隻相位差一個 spread")
	assert_ne(l._phase["u1"], l._phase["u2"], "不同隻不同相位（不同手同腳）")

func test_rebuild_enables_processing_when_monsters_present():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0))])
	assert_true(l.is_processing(), "有怪 → idle 晃動常駐開啟")

func test_rebuild_empty_disables_processing():
	var l := _layer()
	l.rebuild([])
	assert_false(l.is_processing(), "無怪 → 關閉 process")

func test_process_applies_bounded_horizontal_only_sway():
	var l := _layer()
	l.rebuild([{"uid": "u1", "group": "no_such_group", "cell": Vector2i(0, 0), "state": 0}])  # 無 idle2 → 晃動 fallback
	l._process(0.016)
	var s: Sprite3D = l._sprites["u1"]
	var max_px: float = MonsterLayer.SWAY_WORLD / s.pixel_size
	assert_lt(absf(s.offset.x), max_px + 0.0001, "晃動 offset 不超過世界振幅換算")
	assert_almost_eq(s.offset.y, 0.0, 0.0001, "只左右、不上下")

# ---- idle 兩幀假動畫（有 idle2 的怪）----
func test_frame_index_swaps_each_period():
	assert_eq(MonsterLayer.frame_index(0.0, 0.0, 0.4), 0, "t=0 → 第 0 幀")
	assert_eq(MonsterLayer.frame_index(0.4, 0.0, 0.4), 1, "t=period → 第 1 幀")
	assert_eq(MonsterLayer.frame_index(0.8, 0.0, 0.4), 0, "t=2·period → 回第 0 幀")

func test_frame_index_phase_offsets_beat():
	assert_eq(MonsterLayer.frame_index(0.0, 1.0, 0.4), 1, "beat_offset=1 → 提前一拍，t=0 即第 1 幀")

func test_frame_index_guards_zero_period():
	var idx := MonsterLayer.frame_index(0.5, 0.0, 0.0)
	assert_true(idx == 0 or idx == 1, "period=0 → max guard，不崩")

func test_rebuild_stores_frame_a_and_b():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0))])   # group "g" → goblin
	assert_true(l._frames.has("u1"))
	assert_not_null(l._frames["u1"]["a"], "frame A（idle 真圖或 placeholder）非 null")
	assert_true(l._frames["u1"].has("b"), "frame B 鍵存在（值可為 null，goblin_idle_b 未放入時）")

func test_update_frame_swaps_texture_when_second_frame_present():
	var l := _layer()
	l.rebuild([_live("u1", Vector2i(0, 0))])
	var s: Sprite3D = l._sprites["u1"]
	var tex_a = l._frames["u1"]["a"]
	var tex_b := ImageTexture.create_from_image(Image.create(32, 48, false, Image.FORMAT_RGBA8))
	l._frames["u1"]["b"] = tex_b
	l._cur_frame["u1"] = 0
	l._phase["u1"] = 0.0
	l._update_frame("u1", 0.4)   # idx=1 → 切到 b
	assert_eq(s.texture, tex_b, "有第二幀 → t=period 切到 frame B")
	l._update_frame("u1", 0.8)   # idx=0 → 切回 a
	assert_eq(s.texture, tex_a, "回 frame A")

func test_update_frame_falls_back_to_sway_without_second_frame():
	var l := _layer()
	l.rebuild([{"uid": "x1", "group": "no_such_group", "cell": Vector2i(0, 0), "state": 0}])  # placeholder, b=null
	var s: Sprite3D = l._sprites["x1"]
	l._phase["x1"] = 0.0
	l._update_frame("x1", 0.45)
	assert_almost_eq(s.offset.y, 0.0, 0.0001, "fallback 晃動只左右")
	var max_px: float = MonsterLayer.SWAY_WORLD / s.pixel_size
	assert_lt(absf(s.offset.x), max_px + 0.0001)
