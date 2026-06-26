class_name ChestPrompt
extends CanvasLayer

# 程式建構的開箱確認覆蓋層（鏡射 SaveMenu 的 visible/open/close 慣例）。
# [Y] 確認開箱 / [N] 放棄。開啟期間 main 已停用 player 並擋其他選單，無按鍵衝突。

signal confirmed
signal declined

var _label: Label

func is_open() -> bool:
	return visible

func open() -> void:
	visible = true
	set_process_unhandled_input(true)

func close() -> void:
	visible = false
	set_process_unhandled_input(false)

func _ready() -> void:
	layer = 10
	visible = false
	_label = Label.new()
	_label.text = "打開寶箱？  [Y] 開 / [N] 不開"
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.add_theme_font_size_override("font_size", 28)
	add_child(_label)
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_Y:
		close()
		confirmed.emit()
	elif event.keycode == KEY_N:
		close()
		declined.emit()
