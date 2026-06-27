extends GutTest

func _monster(n: String, hp: int) -> Monster:
	var m := Monster.new()
	m.name = n; m.hp = hp; m.hp_max = hp; m.might = 1; m.armor = 0
	m.accuracy = 1; m.speed = 1; m.xp_reward = 1; m.gold_reward = 1
	return m

func _stage_with(monsters: Array) -> CombatStage:
	var cam := Camera3D.new()
	add_child_autofree(cam)
	var st := CombatStage.new()
	add_child_autofree(st)
	st.setup(cam)
	st.rebuild(monsters)
	return st

func _tex(c: Color) -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func test_rebuild_spawns_one_sprite_per_monster():
	var a := _monster("A", 10); var b := _monster("B", 10)
	var st := _stage_with([a, b])
	assert_eq(st._sprites.size(), 2)

func test_refresh_hides_dead():
	var a := _monster("A", 10); var b := _monster("B", 10)
	var st := _stage_with([a, b])
	b.hp = 0
	st.refresh()
	assert_false(st._sprites[b].visible, "死亡怪物 billboard 隱藏")
	assert_true(st._sprites[a].visible)

func test_flash_marks_sprite_tint():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.flash(a)
	assert_gt(st._sprites[a].modulate.r, 1.0, "受擊紅閃：modulate 提亮")

func test_texture_for_state_picks_per_state():
	var base := _tex(Color.GRAY)
	var idle := _tex(Color.GREEN)
	var atk := _tex(Color.RED)
	var hurt := _tex(Color.BLUE)
	var t := {"idle": idle, "attack": atk, "hurt": hurt, "base": base}
	assert_eq(CombatStage.texture_for_state("idle", t), idle)
	assert_eq(CombatStage.texture_for_state("attack", t), atk)
	assert_eq(CombatStage.texture_for_state("hit", t), hurt, "hit 態用 hurt 貼圖")

func test_texture_for_state_falls_back_to_base():
	var base := _tex(Color.GRAY)
	var t := {"idle": null, "attack": null, "hurt": null, "base": base}
	assert_eq(CombatStage.texture_for_state("idle", t), base, "缺該態 → base")
	assert_eq(CombatStage.texture_for_state("attack", t), base)
	assert_eq(CombatStage.texture_for_state("hit", t), base)
	assert_eq(CombatStage.texture_for_state("???", t), base, "不認得的 state → base")
