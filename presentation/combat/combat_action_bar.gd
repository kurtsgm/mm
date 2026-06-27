class_name CombatActionBar
extends Control

# 當前行動者的行動列：[攻擊/防禦/施法/道具/逃跑] 按鈕（含熱鍵字），點擊或熱鍵皆 emit action_selected。
# 上方一行情境提示（選目標/選法術…）。版面貼底、置中，按鈕用 size_flags 平均分攤。
signal action_selected(id: String)

const _LABELS := { "attack": "攻擊", "defend": "防禦", "spell": "施法", "item": "道具", "run": "逃跑" }
const _HOTKEY := { "attack": "1-9", "defend": "D", "spell": "C", "item": "I", "run": "F" }

var _prompt: Label
var _row: HBoxContainer
var _buttons: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	_prompt = Label.new()
	_prompt.anchor_left = 0.15; _prompt.anchor_right = 0.85
	_prompt.anchor_top = 0.80; _prompt.anchor_bottom = 0.80
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 15)
	add_child(_prompt)
	_row = HBoxContainer.new()
	_row.anchor_left = 0.15; _row.anchor_right = 0.85
	_row.anchor_top = 0.84; _row.anchor_bottom = 0.90
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)

# Control 直接掛在 CanvasLayer 下時，於 _ready（add_child 後）才設 anchors 不會被重算尺寸
# → 顯式撐成 viewport 大小並隨視窗縮放（解析度無關）。
func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)   # 相等對向 anchors → size 自由、可顯式設、不被覆寫
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size

static func label_for(id: String) -> String:
	return _LABELS.get(id, id)

func show_actions(actions: Array) -> void:
	for b in _buttons:
		_row.remove_child(b); b.free()
	_buttons.clear()
	for id in actions:
		var btn := Button.new()
		btn.text = "%s[%s]" % [label_for(id), _HOTKEY.get(id, "")]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): action_selected.emit(id))
		_row.add_child(btn)
		_buttons.append(btn)

func set_prompt(text: String) -> void:
	_prompt.text = text
