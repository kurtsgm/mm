extends GutTest

func _knight() -> Character:
	var c := Character.new()
	c.name = "亞爾"
	c.char_class = "Knight"
	c.level = 3
	c.experience = 50
	c.hp = 21
	c.hp_max = 42
	c.sp = 0
	c.sp_max = 0
	c.might = 18
	c.endurance = 20
	c.accuracy = 13
	return c

func _view(c: Character) -> CharacterStatusView:
	var v := CharacterStatusView.new()
	add_child_autofree(v)
	v.refresh(c)
	return v

func test_shows_name_and_class():
	var v := _view(_knight())
	assert_true(v.name_text().contains("亞爾"))

func test_hp_ratio_proportional():
	var v := _view(_knight())
	assert_almost_eq(v.hp_ratio(), 0.5, 0.01)   # 21/42

func test_xp_ratio_proportional():
	var v := _view(_knight())
	assert_almost_eq(v.xp_ratio(), float(50) / float(Leveling.xp_for_level(3)), 0.01)

func test_chip_count_tracks_statuses():
	var c := _knight()
	assert_eq(_view(c).chip_count(), 0)
	c.statuses = [StatusCatalog.poison(2, 3)]
	assert_eq(_view(c).chip_count(), 1)
