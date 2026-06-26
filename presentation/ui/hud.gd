class_name Hud
extends CanvasLayer

# 程式建構的 placeholder HUD：左上指北針、左下訊息列 + 隊伍卡列（PartyPanel）。
# 版面錨定左上/左下，解析度無關（預設視窗 1152x648）。

const _DIR_NAMES := ["N", "E", "S", "W"]  # 以 GridDirection.Dir 索引

var _compass_label: Label
var _message_label: Label
var _party_panel: PartyPanel
var _bound_party: Party
var _message_log: MessageLog

func setup(game_state: Node, player: PlayerController) -> void:
	_build_ui(game_state.party)
	_bound_party = game_state.party
	_message_log = game_state.message_log
	_message_log.changed.connect(_on_message_changed)
	player.facing_changed.connect(_on_facing_changed)

func _build_ui(party: Party) -> void:
	_compass_label = Label.new()
	_compass_label.position = Vector2(20, 12)
	_compass_label.add_theme_font_size_override("font_size", 22)
	add_child(_compass_label)

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

	_party_panel = PartyPanel.new()
	bottom.add_child(_party_panel)
	_party_panel.setup(party)

func refresh() -> void:
	# 讀檔可能整個換掉 GameState.party 實例 → sync 偵測並在需要時重建卡。
	_bound_party = GameState.party
	_party_panel.sync(GameState.party)

func _on_facing_changed(facing: int) -> void:
	_compass_label.text = "面向: %s" % _DIR_NAMES[facing]

func _on_message_changed() -> void:
	var lines := _message_log.recent(1)
	_message_label.text = ("> " + lines[0]) if lines.size() > 0 else ""
