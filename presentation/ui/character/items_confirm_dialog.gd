class_name ItemConfirmDialog
extends Control

# 道具動作確認 modal：羊皮卷置中對話框 + 暗化背景。
# 純呈現：setup(標題, 說明, 選項陣列, 游標) → 重建；選項以整列反白標出游標。
# 版面比例式（寬度依視窗比例），不寫死像素。邏輯（選哪個、確認/取消）留在 CharacterPanel。

var _panel: PanelContainer
var _title: Label
var _prompt: Label
var _options_box: HBoxContainer
var _opt_labels: Array = []
var _cursor: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 暗化背景（蓋住底下的雙欄，聚焦對話框）
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _dialog_stylebox())
	center.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	_panel.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", PanelSkin.TITLE)
	_title.add_theme_font_size_override("font_size", PanelSkin.FONT_HEADER)
	_title.add_theme_constant_override("outline_size", PanelSkin.OUTLINE_SIZE)
	_title.add_theme_color_override("font_outline_color", PanelSkin.OUTLINE_COLOR)
	vb.add_child(_title)

	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_color_override("font_color", PanelSkin.TEXT)
	_prompt.add_theme_font_size_override("font_size", PanelSkin.FONT_BODY)
	vb.add_child(_prompt)

	_options_box = HBoxContainer.new()
	_options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_options_box.add_theme_constant_override("separation", 18)
	vb.add_child(_options_box)

func setup(title: String, prompt: String, options: Array, cursor: int) -> void:
	if _panel == null:
		return
	# 依視窗比例給最小寬度（解析度無關），不寫死像素。
	var vw := get_viewport().get_visible_rect().size.x if get_viewport() != null else 800.0
	_panel.custom_minimum_size = Vector2(maxf(360.0, vw * 0.32), 0)
	_title.text = title
	_prompt.text = prompt
	_cursor = cursor
	for c in _options_box.get_children():
		_options_box.remove_child(c)
		c.queue_free()
	_opt_labels.clear()
	for i in options.size():
		var opt := _make_option(String(options[i]), i == cursor)
		_options_box.add_child(opt)
		_opt_labels.append(opt)

func option_count() -> int:
	return _opt_labels.size()

func option_text(i: int) -> String:
	if i < 0 or i >= _opt_labels.size():
		return ""
	return (_opt_labels[i].get_child(0) as Label).text

func cursor() -> int:
	return _cursor

func title_text() -> String:
	return _title.text if _title != null else ""

func prompt_text() -> String:
	return _prompt.text if _prompt != null else ""

# 選項＝包一層 PanelContainer，游標所在用 row_hilite 反白。
func _make_option(text: String, active: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", PanelSkin.row_hilite_stylebox() if active else _option_idle_stylebox())
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", PanelSkin.TITLE if active else PanelSkin.TEXT)
	l.add_theme_font_size_override("font_size", PanelSkin.FONT_BODY)
	pc.add_child(l)
	return pc

func _option_idle_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.80, 0.71, 0.52, 0.20)
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(1)
	sb.border_color = PanelSkin.FRAME
	sb.set_content_margin_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	return sb

# 羊皮風對話框底：乾淨米底 + 棕外框 + 內金細線，小尺寸也好看（不用大張 9-slice 破邊貼圖）。
func _dialog_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PanelSkin.PARCHMENT
	sb.set_corner_radius_all(10)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = PanelSkin.FRAME
	sb.set_content_margin_all(26)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	return sb
