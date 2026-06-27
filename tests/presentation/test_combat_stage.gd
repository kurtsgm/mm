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
