extends GutTest

func _char(name: String) -> Character:
	var c := Character.new()
	c.name = name
	return c

func test_known_name_returns_texture():
	var tex := PortraitCatalog.texture_for(_char("Gerard"))
	assert_not_null(tex, "Gerard 應有頭像貼圖")
	assert_true(tex is Texture2D)

func test_unknown_name_returns_null():
	assert_null(PortraitCatalog.texture_for(_char("Nobody")))

func test_null_character_returns_null():
	assert_null(PortraitCatalog.texture_for(null))
