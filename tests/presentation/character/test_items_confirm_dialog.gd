extends GutTest

func _dialog(title: String, prompt: String, options: Array, cursor: int) -> ItemConfirmDialog:
	var d := ItemConfirmDialog.new()
	add_child_autofree(d)
	d.setup(title, prompt, options, cursor)
	return d

func test_shows_title_prompt_and_options():
	var d := _dialog("治療藥水", "對 亞爾 使用？", ["使用", "取消"], 0)
	assert_eq(d.option_count(), 2, "兩個選項")
	assert_true(d.option_text(0).contains("使用"), "第一個是動作")
	assert_true(d.option_text(1).contains("取消"), "第二個是取消")
	assert_true(d.title_text().contains("治療藥水"))
	assert_true(d.prompt_text().contains("亞爾"))

func test_marks_cursor_option():
	var d := _dialog("短劍", "裝備？", ["裝備", "取消"], 1)
	assert_eq(d.cursor(), 1, "游標停在取消")

func test_single_option_for_unusable():
	var d := _dialog("治療藥水", "亞爾 現在用不到 治療藥水。", ["確定"], 0)
	assert_eq(d.option_count(), 1, "不可用時只給確定")
	assert_true(d.option_text(0).contains("確定"))
