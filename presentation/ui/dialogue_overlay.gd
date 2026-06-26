class_name DialogueOverlay
extends CanvasLayer
# 全版面圖片 + 對話框 + 選項覆蓋層（鏡射 ChestPrompt 的 visible/open/close/_unhandled_input 慣例）。
# 版面用 anchor 比例（解析度無關）；選項用數字鍵 1..N 選擇。
# 不碰 GameState：effects 描述以 advanced 訊號交給 main 推訊息列。

signal advanced(descriptions: Array)
signal finished

var _runner: DialogueRunner
var _image_rect: TextureRect
var _text_label: Label
var _choice_box: VBoxContainer

func is_open() -> bool:
	return visible

func _ready() -> void:
	layer = 10
	visible = false

	_image_rect = TextureRect.new()
	_image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_image_rect)

	var box := Panel.new()
	# 底部約 30% 高的對話框，左右各留 5% 邊。
	box.anchor_left = 0.05
	box.anchor_right = 0.95
	box.anchor_top = 0.68
	box.anchor_bottom = 0.97
	add_child(box)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_top = 12
	vb.offset_right = -16
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 6)
	box.add_child(vb)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 20)
	vb.add_child(_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	vb.add_child(_choice_box)

	set_process_unhandled_input(false)

func open(runner: DialogueRunner) -> void:
	_runner = runner
	visible = true
	set_process_unhandled_input(true)
	_render()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)

func _render() -> void:
	var node := _runner.current_node()
	_text_label.text = String(node.get("text", ""))
	_image_rect.texture = SceneImageCatalog.get_texture(_resolve_image(node))
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.free()
	var choices := _runner.available_choices()
	if choices.is_empty():
		# 零可選項（末端節點/全被 require 擋下）→ 死路提示，任意鍵離開（避免 soft-lock）。
		var hint := Label.new()
		hint.add_theme_font_size_override("font_size", 18)
		hint.text = "（按任意鍵離開）"
		_choice_box.add_child(hint)
		return
	for i in choices.size():
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.text = "%d) %s" % [i + 1, String(choices[i].get("text", ""))]
		_choice_box.add_child(lbl)

func _resolve_image(node: Dictionary) -> String:
	var img := String(node.get("image", ""))
	if img != "":
		return img
	return String(_runner.current_node().get("image", ""))  # 退回：起始/當前皆無則空 → placeholder

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _runner.available_choices().is_empty():
		# 死路：任意鍵走正常結束路徑（main._on_dialogue_finished 會重新啟用玩家）。
		close()
		finished.emit()
		return
	var idx: int = event.keycode - KEY_1   # KEY_1..KEY_9 → 0..8
	if idx < 0 or idx > 8:
		return
	var choices := _runner.available_choices()
	if idx >= choices.size():
		return
	var descs := _runner.choose(choices[idx])
	if descs.size() > 0:
		advanced.emit(descs)
	if _runner.is_finished():
		close()
		finished.emit()
	else:
		_render()
