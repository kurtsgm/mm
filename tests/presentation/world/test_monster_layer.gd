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
