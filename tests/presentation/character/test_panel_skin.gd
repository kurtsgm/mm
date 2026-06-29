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

# 面板字型必須能渲染「繁體中文」而不破圖（tofu）。
# 回歸測試：先前 base 字型的系統 fallback 漂移到 Songti SC（簡體），
# 繁體獨有字形（騎/聖/盜/準/擊/禦/術/經/驗）變成 .notdef 方框。
func test_panel_font_renders_traditional_chinese_without_tofu():
	var font := PanelSkin.panel_font()
	assert_not_null(font, "panel_font() 應回傳可用字型")
	# 繁體獨有字形 + 面板實際會出現的字，全部都該有字形（非簡繁共用）。
	var sample := "騎聖盜準擊禦術經驗速度精準防禦命中屬性道具法術狀態經驗距下一級"
	var ts := TextServerManager.get_primary_interface()
	var sh := ts.create_shaped_text()
	ts.shaped_text_add_string(sh, sample, font.get_rids(), 24)
	ts.shaped_text_shape(sh)
	var tofu := 0
	for g in ts.shaped_text_get_glyphs(sh):
		if int(g["index"]) == 0 or not (g["font_rid"] as RID).is_valid():
			tofu += 1
	ts.free_rid(sh)
	assert_eq(tofu, 0, "繁體中文不得出現 .notdef 破圖方框（tofu）")
