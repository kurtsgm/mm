class_name CombatChoiceList
extends Control

# 戰鬥子選單（施法/道具共用）：標題 + 編號列。數字鍵或點擊選 → chosen(index)；Esc/取消 → cancelled。
# 純清單呈現，不知道內容語意；由 CombatLayer 決定 rows 與選取後行為。
signal chosen(index: int)
signal cancelled

var _open: bool = false
var _count: int = 0
var _panel: Panel
var _label: Label

func _ready() -> void:
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	visible = false
	_panel = Panel.new()
	_panel.anchor_left = 0.30; _panel.anchor_right = 0.70
	_panel.anchor_top = 0.40; _panel.anchor_bottom = 0.66
	add_child(_panel)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 12; _label.offset_top = 8
	_label.offset_right = -12; _label.offset_bottom = -8
	_label.add_theme_font_size_override("font_size", 15)
	_panel.add_child(_label)

# Control 直接掛在 CanvasLayer 下時，於 _ready（add_child 後）才設 anchors 不會被重算尺寸
# → 顯式撐成 viewport 大小並隨視窗縮放（解析度無關）。
func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)   # 相等對向 anchors → size 自由、可顯式設、不被覆寫
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size

func open(title: String, rows: Array) -> void:
	_count = rows.size()
	var lines: Array[String] = [title]
	for i in rows.size():
		lines.append("[%d] %s" % [i + 1, rows[i]])
	lines.append("[Esc] 返回")
	_label.text = "\n".join(lines)
	_open = true
	visible = true

func close() -> void:
	_open = false
	visible = false

func is_open() -> bool:
	return _open

func choose(index: int) -> void:
	if index >= 0 and index < _count:
		chosen.emit(index)

func handle_key(keycode: int) -> void:
	if not _open:
		return
	if keycode == KEY_ESCAPE:
		close()
		cancelled.emit()
	elif keycode >= KEY_1 and keycode <= KEY_9:
		choose(keycode - KEY_1)
