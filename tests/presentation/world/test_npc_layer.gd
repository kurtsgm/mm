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
