class_name TravelOverlay
extends CanvasLayer
# 比例式旅行選單覆蓋層：踩到 travel 格開啟，[↑↓]選目的地 [Enter]出發 [Esc]離開。
# 選定目的地以 travel_chosen 交給 main 執行 _enter_via_link；不自行切圖、不碰 message_log。

signal travel_chosen(node: Dictionary)
signal finished

var _nodes: Array = []
var _cursor := 0
var _title: Label
var _list: Label

func _ready() -> void:
	layer = 11
	visible = false
	var panel := Panel.new()
	panel.anchor_left = 0.32
	panel.anchor_right = 0.68
	panel.anchor_top = 0.30
	panel.anchor_bottom = 0.70
	add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_top = 12
	box.offset_right = -16
	box.offset_bottom = -12
	panel.add_child(box)
	_title = Label.new()
	_title.text = "旅行——選擇目的地"
	box.add_child(_title)
	_list = Label.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_list)
	var hint := Label.new()
	hint.text = "↑↓ 選擇　Enter 出發　Esc 離開"
	box.add_child(hint)
	set_process_unhandled_input(false)

func is_open() -> bool:
	return visible

func list_text() -> String:
	return _list.text

func open(nodes: Array) -> void:
	_nodes = nodes
	_cursor = 0
	visible = true
	set_process_unhandled_input(true)
	_render()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)

func _render() -> void:
	if _nodes.is_empty():
		_list.text = "（目前沒有可前往的目的地）"
		return
	var lines: Array = []
	for i in _nodes.size():
		var n: Dictionary = _nodes[i]
		var mark = "▶ " if i == _cursor else "　 "
		lines.append("%s%s" % [mark, String(n.get("name", n.get("id", "?")))])
	_list.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	match event.keycode:
		KEY_ESCAPE:
			close()
			finished.emit()
		KEY_UP:
			if _nodes.size() > 0:
				_cursor = (_cursor - 1 + _nodes.size()) % _nodes.size()
				_render()
		KEY_DOWN:
			if _nodes.size() > 0:
				_cursor = (_cursor + 1) % _nodes.size()
				_render()
		KEY_ENTER, KEY_KP_ENTER:
			if _nodes.size() > 0:
				var n: Dictionary = _nodes[_cursor]
				close()
				travel_chosen.emit(n)
