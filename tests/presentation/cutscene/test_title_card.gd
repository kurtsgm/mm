extends GutTest

func _card() -> TitleCard:
	var c := TitleCard.new()
	add_child_autofree(c)
	return c

func test_full_rect_ratio_anchors():
	var c := _card()
	# 版面比例式（解析度無關）：占滿全螢幕作黑底標題。
	assert_almost_eq(c.anchor_left, 0.0, 0.001)
	assert_almost_eq(c.anchor_right, 1.0, 0.001)
	assert_almost_eq(c.anchor_top, 0.0, 0.001)
	assert_almost_eq(c.anchor_bottom, 1.0, 0.001)

func test_set_content_fills_labels():
	var c := _card()
	c.set_content("第一章", "邊陲在地英雄")
	assert_eq(c._title_label.text, "第一章")
	assert_eq(c._subtitle_label.text, "邊陲在地英雄")

func test_empty_subtitle_hides_it():
	var c := _card()
	c.set_content("第一章", "")
	assert_false(c._subtitle_label.visible)
