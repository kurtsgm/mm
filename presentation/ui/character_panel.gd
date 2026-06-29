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

enum Mode { LIST = 0, PICK_TARGET = 1 }
var _mode: int = Mode.LIST
var _target_cursor: int = 0
var _pending_spell: SpellDef = null

var _footer: Label
var _rail: PartyRail
var _status_view: CharacterStatusView
var _list_text: RichTextLabel       # items / spells 分頁的清單文字（BBCode 高亮游標列）
var _tabbar: HBoxContainer
var _content: Control               # 內容容器（status_view 與 list_text 疊放、依分頁切顯示）

func is_open() -> bool:
	return visible

func current_tab() -> int:
	return _tab

func selected_index() -> int:
	return _member_idx

func open(tab: int, state) -> void:
	_state = state
	_tab = tab
	_member_idx = 0
	_item_cursor = 0
	_spell_cursor = 0
	_mode = Mode.LIST
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
	_mode = Mode.LIST
	_refresh()

func _ready() -> void:
	layer = 10
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := Panel.new()
	box.anchor_left = 0.10
	box.anchor_right = 0.90
	box.anchor_top = 0.10
	box.anchor_bottom = 0.90
	box.add_theme_stylebox_override("panel", PanelSkin.frame_stylebox())
	add_child(box)

	# 半透明米色閱讀底：壓淡羊皮中央斑漬好讀；疊在 root 之下、紋理破邊照樣露出。
	var reading := Panel.new()
	reading.anchor_left = 0.07
	reading.anchor_top = 0.08
	reading.anchor_right = 0.93
	reading.anchor_bottom = 0.92
	reading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reading.add_theme_stylebox_override("panel", PanelSkin.reading_stylebox())
	box.add_child(reading)

	var root := HBoxContainer.new()
	# 比例內縮，避開羊皮貼圖的燒灼破邊（不壓到深色邊、內容留在乾淨中央）。
	root.anchor_left = 0.08
	root.anchor_top = 0.09
	root.anchor_right = 0.92
	root.anchor_bottom = 0.91
	root.add_theme_constant_override("separation", 12)
	box.add_child(root)

	# 左：隊員直欄（約 1/4 寬，比例式）
	_rail = PartyRail.new()
	_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rail.size_flags_stretch_ratio = 0.28
	root.add_child(_rail)

	# 右：主區（分頁列 + 內容 + footer）
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 0.72
	main.add_theme_constant_override("separation", 8)
	root.add_child(main)

	_tabbar = HBoxContainer.new()
	_tabbar.add_theme_constant_override("separation", 6)
	main.add_child(_tabbar)

	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(_content)
	_status_view = CharacterStatusView.new()
	_status_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(_status_view)
	_list_text = RichTextLabel.new()
	_list_text.bbcode_enabled = true
	_list_text.fit_content = true
	_list_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list_text.add_theme_color_override("default_color", PanelSkin.TEXT)
	_list_text.add_theme_constant_override("outline_size", PanelSkin.OUTLINE_SIZE)
	_list_text.add_theme_color_override("font_outline_color", PanelSkin.OUTLINE_COLOR)
	_content.add_child(_list_text)

	_footer = Label.new()
	_footer.add_theme_color_override("font_color", PanelSkin.SECTION)
	_footer.add_theme_font_size_override("font_size", 18)
	_footer.add_theme_constant_override("outline_size", PanelSkin.OUTLINE_SIZE)
	_footer.add_theme_color_override("font_outline_color", PanelSkin.OUTLINE_COLOR)
	main.add_child(_footer)

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
	if _tab == Tab.SPELLS and _mode == Mode.PICK_TARGET:
		_input_pick_target(event.keycode)
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		_select_member_index(event.keycode - KEY_1)
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

# 數字鍵 1-6 直接選第 idx+1 位隊員；超出隊伍人數則忽略。
func _select_member_index(idx: int) -> void:
	if idx < 0 or idx >= _members().size():
		return
	_member_idx = idx
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
	var rows := CharacterSpellsTab.rows(_selected_member())
	if _spell_cursor < 0 or _spell_cursor >= rows.size():
		return
	if not bool(rows[_spell_cursor]["field"]):
		return   # 戰鬥限定，野外不可施放
	var spell: SpellDef = rows[_spell_cursor]["spell"]
	var caster := _selected_member()
	match spell.effect:
		SpellDef.Effect.TELEPORT, SpellDef.Effect.RECALL:
			if not _pay(caster, spell):
				return
			world_spell_cast.emit(spell)
			close()
		_:
			if spell.target == SpellDef.Target.ALL_ALLIES:
				if not _pay(caster, spell):
					return
				for m in _members():
					for e in SpellEffects.apply(spell, caster, m):
						_push(String(e))
				_refresh()
			else:
				_pending_spell = spell
				_target_cursor = 0
				_mode = Mode.PICK_TARGET
				_refresh()

func _input_pick_target(key: int) -> void:
	var ms := _members()
	match key:
		KEY_ESCAPE:
			_mode = Mode.LIST
			_refresh()
		KEY_UP:
			if ms.size() > 0:
				_target_cursor = (_target_cursor - 1 + ms.size()) % ms.size()
				_refresh()
		KEY_DOWN:
			if ms.size() > 0:
				_target_cursor = (_target_cursor + 1) % ms.size()
				_refresh()
		KEY_ENTER, KEY_KP_ENTER:
			_confirm_pick_target()

func _confirm_pick_target() -> void:
	var ms := _members()
	if _target_cursor < 0 or _target_cursor >= ms.size():
		return
	var target: Character = ms[_target_cursor]
	var caster := _selected_member()
	if not SpellEffects.can_cast(_pending_spell, caster, target):
		_push("無法對 %s 施放 %s。" % [target.name, _pending_spell.display_name])
		_mode = Mode.LIST
		_refresh()
		return
	if not _pay(caster, _pending_spell):
		_mode = Mode.LIST
		_refresh()
		return
	for e in SpellEffects.apply(_pending_spell, caster, target):
		_push(String(e))
	_mode = Mode.LIST
	_refresh()

func _pay(caster: Character, spell: SpellDef) -> bool:
	if caster.sp < spell.sp_cost:
		_push("%s 的 SP 不足。" % caster.name)
		return false
	caster.sp -= spell.sp_cost
	return true

func _refresh() -> void:
	_clamp_cursors()
	_rail.refresh(_members(), _member_idx)
	_rebuild_tabbar()
	var is_status := _tab == Tab.STATUS
	_status_view.visible = is_status
	_list_text.visible = not is_status
	if is_status:
		_status_view.refresh(_selected_member())
	else:
		_apply_list_text()
	_footer.text = _footer_text()

func _rebuild_tabbar() -> void:
	for c in _tabbar.get_children():
		c.queue_free()
		_tabbar.remove_child(c)
	var names := ["狀態", "道具", "法術"]
	for i in names.size():
		var t := Label.new()
		t.text = names[i]
		t.add_theme_stylebox_override("normal", PanelSkin.tab_stylebox(i == _tab))
		t.add_theme_color_override("font_color", Color(0.95, 0.90, 0.77) if i == _tab else PanelSkin.SECTION)
		t.add_theme_font_size_override("font_size", 20)
		_tabbar.add_child(t)

# items/spells：用既有 _body_lines() 取字串，cursor 列（以 "> " 開頭）以金色粗體高亮。
func _apply_list_text() -> void:
	var lines := _body_lines()
	var out: Array[String] = []
	for ln in lines:
		var s := String(ln)
		var safe := s.replace("[", "[lb]")
		if s.begins_with("> "):
			out.append("[b][color=#b8923f]%s[/color][/b]" % safe)
		else:
			out.append(safe)
	_list_text.text = "\n".join(out)

# 目前分頁的文字鏡像（供測試/可及性；status 用 lines() 不用 widget 文字）。
func body_text() -> String:
	if _tab == Tab.STATUS:
		return "\n".join(CharacterStatusTab.lines(_selected_member()))
	return "\n".join(_body_lines())

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
			if _mode == Mode.PICK_TARGET:
				return _pick_target_lines()
			return CharacterSpellsTab.lines(CharacterSpellsTab.rows(_selected_member()), _spell_cursor)
	return []

func _footer_text() -> String:
	match _tab:
		Tab.STATUS:
			return "[←→]分頁  [Tab/1-6]換隊員  [Esc]關閉"
		Tab.ITEMS:
			return "[←→]分頁  [Tab/1-6]換隊員  [↑↓]選擇  [Enter]使用/裝備/卸下  [Esc]關閉"
		Tab.SPELLS:
			if _mode == Mode.PICK_TARGET:
				return "[↑↓]選對象  [Enter]確定  [Esc]返回"
			return "[←→]分頁  [Tab/1-6]換隊員  [↑↓]選擇  [Enter]施放  [Esc]關閉"
	return ""

func _pick_target_lines() -> Array:
	var out: Array = ["選擇對象（%s）：" % _pending_spell.display_name]
	var ms := _members()
	for i in ms.size():
		var m: Character = ms[i]
		var mark := "> " if i == _target_cursor else "  "
		out.append("%s%s  Lv%d  HP%d/%d" % [mark, m.name, m.level, m.hp, m.hp_max])
	return out
