class_name CharacterPanel
extends CanvasLayer

# 統一角色面板：status / items / spells 三分頁，取代舊 InventoryMenu / SpellMenu。
# 版面比例式（參考 VendorOverlay）。輸入：[←→]分頁 [Tab/Shift+Tab]隊員 [↑↓]清單 [Enter]動作 [Esc]關。
# C/I/M（開啟與直跳分頁）由 main.gd 處理（面板不攔 C/I/M，避免雙重處理）。

signal closed
signal world_spell_cast(spell: SpellDef)

enum Tab { STATUS = 0, ITEMS = 1, SPELLS = 2 }

var _state                       # GameState 或測試假物件（需 party.members / inventory / message_log）
var _tab: int = Tab.STATUS
var _member_idx: int = 0
var _item_cursor: int = 0
var _spell_cursor: int = 0

var _header: Label
var _body: Label
var _footer: Label

func is_open() -> bool:
	return visible

func current_tab() -> int:
	return _tab

func selected_index() -> int:
	return _member_idx

func body_text() -> String:
	return _body.text

func open(tab: int, state) -> void:
	_state = state
	_tab = tab
	_member_idx = 0
	_item_cursor = 0
	_spell_cursor = 0
	visible = true
	set_process_unhandled_input(true)
	_refresh()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	closed.emit()

func set_tab(tab: int) -> void:
	_tab = tab
	_item_cursor = 0
	_spell_cursor = 0
	_refresh()

func _ready() -> void:
	layer = 10
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := Panel.new()
	box.anchor_left = 0.12
	box.anchor_right = 0.88
	box.anchor_top = 0.10
	box.anchor_bottom = 0.90
	add_child(box)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20
	vb.offset_top = 16
	vb.offset_right = -20
	vb.offset_bottom = -16
	box.add_child(vb)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 18)
	vb.add_child(_header)
	_body = Label.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("font_size", 16)
	vb.add_child(_body)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 14)
	vb.add_child(_footer)
	set_process_unhandled_input(false)

func _members() -> Array:
	return _state.party.members

func _selected_member() -> Character:
	var ms := _members()
	if _member_idx < 0 or _member_idx >= ms.size():
		return null
	return ms[_member_idx]

func _push(text: String) -> void:
	_state.message_log.push(text)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			close()
		KEY_LEFT:
			_switch_tab(-1)
		KEY_RIGHT:
			_switch_tab(1)
		KEY_TAB:
			_switch_member(-1 if event.shift_pressed else 1)
		KEY_UP:
			_move_cursor(-1)
		KEY_DOWN:
			_move_cursor(1)
		KEY_ENTER, KEY_KP_ENTER:
			_activate()

func _switch_tab(d: int) -> void:
	_tab = (_tab + d + 3) % 3
	_item_cursor = 0
	_spell_cursor = 0
	_refresh()

func _switch_member(d: int) -> void:
	var n := _members().size()
	if n > 0:
		_member_idx = (_member_idx + d + n) % n
	_item_cursor = 0
	_spell_cursor = 0
	_refresh()

func _move_cursor(d: int) -> void:
	if _tab == Tab.ITEMS:
		var n := CharacterItemsTab.rows(_selected_member(), _state.inventory).size()
		if n > 0:
			_item_cursor = (_item_cursor + d + n) % n
	elif _tab == Tab.SPELLS:
		var n := CharacterSpellsTab.rows(_selected_member()).size()
		if n > 0:
			_spell_cursor = (_spell_cursor + d + n) % n
	_refresh()

func _activate() -> void:
	match _tab:
		Tab.ITEMS:
			_activate_item()
		Tab.SPELLS:
			_activate_spell()

func _activate_item() -> void:
	var rows := CharacterItemsTab.rows(_selected_member(), _state.inventory)
	if _item_cursor < 0 or _item_cursor >= rows.size():
		return
	var events := CharacterItemsTab.activate(rows[_item_cursor], _selected_member(), _state.inventory)
	for e in events:
		_push(String(e))
	_refresh()

func _activate_spell() -> void:
	pass   # Task 6

func _refresh() -> void:
	_clamp_cursors()
	var c := _selected_member()
	var who := "◄ %s  Lv%d ►" % [c.name, c.level] if c != null else "-"
	var names := ["Status", "Items", "Spells"]
	var tbar := ""
	for i in names.size():
		tbar += ("[%s] " % names[i]) if i == _tab else ("%s  " % names[i])
	_header.text = "%s        %s" % [who, tbar]
	_body.text = "\n".join(_body_lines())
	_footer.text = _footer_text()

func _clamp_cursors() -> void:
	var ni := CharacterItemsTab.rows(_selected_member(), _state.inventory).size()
	if _item_cursor >= ni:
		_item_cursor = maxi(0, ni - 1)
	var ns := CharacterSpellsTab.rows(_selected_member()).size()
	if _spell_cursor >= ns:
		_spell_cursor = maxi(0, ns - 1)

func _body_lines() -> Array:
	match _tab:
		Tab.STATUS:
			return CharacterStatusTab.lines(_selected_member())
		Tab.ITEMS:
			return CharacterItemsTab.lines(CharacterItemsTab.rows(_selected_member(), _state.inventory), _item_cursor)
		Tab.SPELLS:
			return CharacterSpellsTab.lines(CharacterSpellsTab.rows(_selected_member()), _spell_cursor)
	return []

func _footer_text() -> String:
	match _tab:
		Tab.STATUS:
			return "[←→]分頁  [Tab]換隊員  [Esc]關閉"
		Tab.ITEMS:
			return "[←→]分頁  [Tab]換隊員  [↑↓]選擇  [Enter]使用/裝備/卸下  [Esc]關閉"
		Tab.SPELLS:
			return "[←→]分頁  [Tab]換隊員  [↑↓]選擇  [Enter]施放  [Esc]關閉"
	return ""
