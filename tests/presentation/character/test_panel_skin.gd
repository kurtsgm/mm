extends GutTest

func test_make_bar_ratio_is_proportional():
	var bar := PanelSkin.make_bar(Color(0.8, 0.2, 0.2))
	add_child_autofree(bar["root"])
	assert_true(bar["root"] is ColorRect, "root 為條背景")
	assert_true(bar["fill"] is ColorRect, "fill 為填色")
	assert_almost_eq(bar["fill"].anchor_right, 0.0, 0.001, "初始為 0")
	PanelSkin.set_ratio(bar, 0.5)
	assert_almost_eq(bar["fill"].anchor_right, 0.5, 0.001, "比例式填色（非寫死寬）")
	PanelSkin.set_ratio(bar, 2.0)
	assert_almost_eq(bar["fill"].anchor_right, 1.0, 0.001, "夾在 1.0")

func test_make_chip_text_and_node():
	var chip := PanelSkin.make_chip("毒", Color(0.3, 0.6, 0.2))
	add_child_autofree(chip)
	assert_true(chip is Label)
	assert_eq(chip.text, "毒")

func test_styleboxes_exist():
	# frame 改為羊皮貼圖（StyleBoxTexture）；其餘仍為程式化 StyleBoxFlat。
	assert_true(PanelSkin.frame_stylebox() is StyleBoxTexture)
	assert_true(PanelSkin.tab_stylebox(true) is StyleBoxFlat)
	assert_true(PanelSkin.tab_stylebox(false) is StyleBoxFlat)
	assert_true(PanelSkin.row_hilite_stylebox() is StyleBoxFlat)
