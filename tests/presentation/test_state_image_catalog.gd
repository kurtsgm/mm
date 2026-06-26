extends GutTest

func _char(name: String) -> Character:
	var c := Character.new()
	c.name = name
	return c

func test_female_names_are_female():
	assert_eq(StateImageCatalog.gender_for(_char("Cordelia")), "female")
	assert_eq(StateImageCatalog.gender_for(_char("Sira")), "female")
	assert_eq(StateImageCatalog.gender_for(_char("Cassia")), "female")

func test_default_gender_is_male():
	assert_eq(StateImageCatalog.gender_for(_char("Gerard")), "male")

func test_unconscious_path_by_gender():
	assert_eq(StateImageCatalog.state_path(_char("Cordelia"), PortraitState.Face.UNCONSCIOUS), "res://content/portraits/states/down_female.png")
	assert_eq(StateImageCatalog.state_path(_char("Gerard"), PortraitState.Face.UNCONSCIOUS), "res://content/portraits/states/down_male.png")

func test_dead_path_is_tombstone():
	assert_eq(StateImageCatalog.state_path(_char("Gerard"), PortraitState.Face.DEAD), "res://content/portraits/states/tombstone.png")

func test_non_down_states_have_no_path():
	assert_eq(StateImageCatalog.state_path(_char("Gerard"), PortraitState.Face.OK), "")
	assert_eq(StateImageCatalog.state_path(_char("Gerard"), PortraitState.Face.HURT), "")

func test_override_texture_null_for_stateless_face():
	# 非暈倒/死亡（無共用圖路徑）→ override 永遠回 null（卡片用頭像）
	assert_null(StateImageCatalog.override_texture(_char("Gerard"), PortraitState.Face.OK))
