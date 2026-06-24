class_name Hud
extends CanvasLayer

# 程式建構的 placeholder HUD（無真美術）：上方指北針、下方一排隊伍格、面板上方一行訊息。
# 版面座標以預設視窗（1152x648）為準，屬 placeholder，內容期再做正式 UI。

const _DIR_NAMES := ["N", "E", "S", "W"]  # 以 GridDirection.Dir 索引

var _compass_label: Label
var _message_label: Label
var _member_labels: Array[Label] = []
var _message_log: MessageLog

func setup(game_state: Node, player: PlayerController) -> void:
	_build_ui(game_state.party)
	_message_log = game_state.message_log
	_message_log.changed.connect(_on_message_changed)
	player.facing_changed.connect(_on_facing_changed)
	_refresh_party(game_state.party)

func _build_ui(party: Party) -> void:
	# 指北針：左上角（origin 起算，任何解析度都貼齊左上，含全螢幕）。
	_compass_label = Label.new()
	_compass_label.position = Vector2(20, 12)
	_compass_label.add_theme_font_size_override("font_size", 22)
	add_child(_compass_label)

	# 訊息列 + 隊伍面板：錨定畫面左下、自動向上＋向右長 → 解析度無關。
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 20
	bottom.offset_bottom = -20
	bottom.grow_horizontal = Control.GROW_DIRECTION_END
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 8)
	add_child(bottom)

	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 18)
	bottom.add_child(_message_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bottom.add_child(row)
	for i in party.members.size():
		var cell := Label.new()
		cell.custom_minimum_size = Vector2(150, 110)
		row.add_child(cell)
		_member_labels.append(cell)

func _refresh_party(party: Party) -> void:
	for i in _member_labels.size():
		_member_labels[i].text = _format_member(party.members[i])

func _format_member(c: Character) -> String:
	var cond := "OK"
	if c.condition == Character.Condition.UNCONSCIOUS:
		cond = "KO"
	elif c.condition == Character.Condition.DEAD:
		cond = "DEAD"
	return "%s\n%s Lv%d\nHP %d/%d\nSP %d/%d\n[%s]" % [
		c.name, c.char_class, c.level, c.hp, c.hp_max, c.sp, c.sp_max, cond]

func _on_facing_changed(facing: int) -> void:
	_compass_label.text = "面向: %s" % _DIR_NAMES[facing]

func _on_message_changed() -> void:
	var lines := _message_log.recent(1)
	_message_label.text = ("> " + lines[0]) if lines.size() > 0 else ""
