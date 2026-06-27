class_name QuestToast
extends CanvasLayer
# 任務事件瞬間提示：畫面上方置中橫幅，淡入即顯→停留→淡出，多則依序排隊。
# 佇列狀態（_queue/_showing）可單元測；_draw/動畫不做像素測試（HUD 慣例）。

const HOLD := 2.5      # 單則停留秒數

var _queue: Array[String] = []
var _showing: bool = false
var _panel: Panel
var _label: Label

func show_notice(text: String) -> void:
	_queue.append(text)
	if not _showing:
		_advance()

func _ready() -> void:
	layer = 11
	visible = false
	_panel = Panel.new()
	_panel.anchor_left = 0.25
	_panel.anchor_right = 0.75
	_panel.anchor_top = 0.06
	_panel.anchor_bottom = 0.13
	add_child(_panel)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 20)
	_panel.add_child(_label)

func _advance() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	_showing = true
	_label.text = _queue.pop_front()
	visible = true
	_panel.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(HOLD)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_advance)
