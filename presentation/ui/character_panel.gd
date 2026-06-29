class_name CharacterPanel
extends CanvasLayer

# 統一角色面板：status / items / spells 三分頁，取代舊 InventoryMenu / SpellMenu。
# 版面比例式（參考 VendorOverlay）。輸入：[←→]分頁/道具左右欄 [Tab/Shift+Tab]切分頁 [1-6]換隊員 [↑↓]清單 [Enter]動作 [Esc]關。
# C/I/M（開啟與直跳分頁）由 main.gd 處理（面板不攔 C/I/M，避免雙重處理）。
# 道具分頁：分頁與左右欄排成同一水平軸，←→ 連續貫穿、邊界外溢切分頁；Tab 則直接循環分頁。

signal closed
signal world_spell_cast(spell: SpellDef)

enum Tab { STATUS = 0, ITEMS = 1, SPELLS = 2 }

var _state                       # GameState 或測試假物件（需 party.members / inventory / message_log）
var _tab: int = Tab.STATUS
var _member_idx: int = 0
# 道具分頁游標：欄位感知（0=裝備欄, 1=背包欄），各欄記住自己的游標。
var _item_zone: int = 0
var _equip_cursor: int = 0
var _bag_cursor: int = 0
var _spell_cursor: int = 0

enum Mode { LIST = 0, PICK_TARGET = 1, ITEM_CONFIRM = 2 }
var _mode: int = Mode.LIST
var _target_cursor: int = 0
var _pending_spell: SpellDef = null
# 道具動作確認 modal 的暫存狀態
var _confirm_row: Dictionary = {}
var _confirm_action: String = ""   # 使用 / 裝備 / 卸下
var _confirm_cursor: int = 0

var _footer: Label
var _rail: PartyRail
var _status_view: CharacterStatusView
var _items_view: CharacterItemsView  # 道具分頁的雙欄視覺（裝備 / 背包）
var _confirm_dialog: ItemConfirmDialog  # 道具動作確認 modal（疊在最上層）
var _list_text: RichTextLabel       # spells 分頁的清單文字（BBCode 高亮游標列）
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
	_reset_item_cursor()
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
	_reset_item_cursor()
	_spell_cursor = 0
	_mode = Mode.LIST
	_refresh()

func _reset_item_cursor() -> void:
	_item_zone = 0
	_equip_cursor = 0
	_bag_cursor = 0

func item_zone() -> int:
	return _item_zone

func _ready() -> void:
	layer = 10
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 羊皮卷外框佔畫面 ~90%（依比例、解析度無關）。貼圖含烤焦破邊＋外圍棕色暈，
	# 9-slice 的角落/邊（PanelSkin.FRAME_MARGIN 像素）即那圈邊框，故內容要再內縮避開。
	var box := Panel.new()
	box.anchor_left = 0.025
	box.anchor_right = 0.975
	box.anchor_top = 0.04
	box.anchor_bottom = 0.96
	box.add_theme_stylebox_override("panel", PanelSkin.frame_stylebox())
	add_child(box)

	# 面板字型（英文襯線 + 中文宋體）+ 加大的預設字級；全面板子節點繼承。
	# default_font_size 一處放大整個面板（個別需更大的元素再 override）。
	var th := Theme.new()
	th.default_font_size = PanelSkin.FONT_BODY
	var pf := PanelSkin.panel_font()
	if pf != null:
		th.default_font = pf
	box.theme = th

	# 內容直接放在羊皮乾淨中央（用比例錨點貼齊乾淨區內側，避開外圈做舊/破邊）。
	# 不再疊半透明閱讀底——新羊皮中央本身就乾淨，省掉那塊突兀的矩形。
	var root := HBoxContainer.new()
	root.anchor_left = PanelSkin.PARCH_INNER_L
	root.anchor_right = 1.0 - PanelSkin.PARCH_INNER_R
	root.anchor_top = PanelSkin.PARCH_INNER_T
	root.anchor_bottom = 1.0 - PanelSkin.PARCH_INNER_B
	root.add_theme_constant_override("separation", 16)
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
	_items_view = CharacterItemsView.new()
	_items_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(_items_view)
	_list_text = RichTextLabel.new()
	_list_text.bbcode_enabled = true
	_list_text.fit_content = true
	_list_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list_text.add_theme_color_override("default_color", PanelSkin.TEXT)
	_list_text.add_theme_constant_override("outline_size", PanelSkin.OUTLINE_SIZE)
	_list_text.add_theme_color_override("font_outline_color", PanelSkin.OUTLINE_COLOR)
	_list_text.add_theme_font_size_override("normal_font_size", PanelSkin.FONT_BODY)
	_list_text.add_theme_font_size_override("bold_font_size", PanelSkin.FONT_BODY)
	_content.add_child(_list_text)

	_footer = Label.new()
	_footer.add_theme_color_override("font_color", PanelSkin.SECTION)
	_footer.add_theme_font_size_override("font_size", PanelSkin.FONT_FOOTER)
	_footer.add_theme_constant_override("outline_size", PanelSkin.OUTLINE_SIZE)
	_footer.add_theme_color_override("font_outline_color", PanelSkin.OUTLINE_COLOR)
	main.add_child(_footer)

	# 道具動作確認 modal：疊在整個面板之上、置中、預設隱藏（沿用面板字型主題）。
	_confirm_dialog = ItemConfirmDialog.new()
	_confirm_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_dialog.theme = th
	_confirm_dialog.visible = false
	add_child(_confirm_dialog)

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
	if _tab == Tab.ITEMS and _mode == Mode.ITEM_CONFIRM:
		_input_item_confirm(event.keycode)
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		_select_member_index(event.keycode - KEY_1)
		return
	match event.keycode:
		KEY_ESCAPE:
			close()
		KEY_LEFT:
			_horizontal(-1)
		KEY_RIGHT:
			_horizontal(1)
		KEY_TAB:
			_switch_tab(-1 if event.shift_pressed else 1)
		KEY_UP:
			_move_cursor(-1)
		KEY_DOWN:
			_move_cursor(1)
		KEY_ENTER, KEY_KP_ENTER:
			_activate()

# 水平軸：上方分頁與道具左右欄排成同一條線，←→ 連續貫穿；
# 在道具欄走到邊界（裝備欄再左 / 背包欄再右）則「外溢」切換到相鄰分頁。
func _horizontal(d: int) -> void:
	if _tab != Tab.ITEMS:
		_switch_tab(d)
		return
	var rows := _item_rows()
	var has_bag := rows.size() > _equip_n(rows)
	if d > 0:
		if _item_zone == 0 and has_bag:
			_item_zone = 1
			_refresh()
		else:
			_switch_tab(1)    # 背包(或無背包的裝備)再往右 → 外溢到下一分頁
	else:
		if _item_zone == 1:
			_item_zone = 0
			_refresh()
		else:
			_switch_tab(-1)   # 裝備再往左 → 外溢到上一分頁

func _switch_tab(d: int) -> void:
	_tab = (_tab + d + 3) % 3
	_spell_cursor = 0
	_enter_item_zone_by_dir(d)
	_refresh()

# 進入道具分頁時依移動方向落在最近的欄：從左邊(→)進落「裝備」、從右邊(←)進落「背包」。
func _enter_item_zone_by_dir(d: int) -> void:
	_equip_cursor = 0
	_bag_cursor = 0
	if _tab == Tab.ITEMS and d < 0:
		var rows := _item_rows()
		_item_zone = 1 if rows.size() > _equip_n(rows) else 0
	else:
		_item_zone = 0

# 數字鍵 1-6 直接選第 idx+1 位隊員；超出隊伍人數則忽略。
func _select_member_index(idx: int) -> void:
	if idx < 0 or idx >= _members().size():
		return
	_member_idx = idx
	_reset_item_cursor()
	_spell_cursor = 0
	_refresh()

func _move_cursor(d: int) -> void:
	if _tab == Tab.ITEMS:
		var rows := _item_rows()
		var eq := _equip_n(rows)
		if _item_zone == 0:
			if eq > 0:
				_equip_cursor = (_equip_cursor + d + eq) % eq
		else:
			var bag := rows.size() - eq
			if bag > 0:
				_bag_cursor = (_bag_cursor + d + bag) % bag
	elif _tab == Tab.SPELLS:
		var n := CharacterSpellsTab.rows(_selected_member()).size()
		if n > 0:
			_spell_cursor = (_spell_cursor + d + n) % n
	_refresh()

# 道具列（CharacterItemsTab.rows）+ 衍生工具。
func _item_rows() -> Array:
	return CharacterItemsTab.rows(_selected_member(), _state.inventory)

func _equip_n(rows: Array) -> int:
	var n := 0
	for r in rows:
		if String(r.get("kind", "")) == "equip":
			n += 1
	return n

# 目前作用列在 rows 中的全域索引（裝備列在前、背包列在後）。
func _item_index() -> int:
	var rows := _item_rows()
	var eq := _equip_n(rows)
	if _item_zone == 0:
		return clampi(_equip_cursor, 0, maxi(0, eq - 1))
	return eq + clampi(_bag_cursor, 0, maxi(0, rows.size() - eq - 1))

func _activate() -> void:
	match _tab:
		Tab.ITEMS:
			_activate_item()
		Tab.SPELLS:
			_activate_spell()

# Enter 不直接動作，改開確認 modal；空槽等無動作則不開。
func _activate_item() -> void:
	var rows := _item_rows()
	var idx := _item_index()
	if idx < 0 or idx >= rows.size():
		return
	var row: Dictionary = rows[idx]
	var action := _item_action_for(row)
	if action == "":
		return
	_confirm_row = row
	_confirm_action = action
	_confirm_cursor = 0
	_mode = Mode.ITEM_CONFIRM
	_refresh()

# 該列在 Enter 時的動作字串：使用 / 裝備 / 卸下；無可做動作則回空字串。
func _item_action_for(row: Dictionary) -> String:
	var m := _selected_member()
	if String(row.get("kind", "")) == "equip":
		return "卸下" if m.equipment.is_equipped(int(row["slot"])) else ""
	var item := ItemCatalog.get_item(String(row.get("id", "")))
	if item == null:
		return ""
	if item.is_consumable():
		return "使用"
	if m.equipment.can_equip(item):
		return "裝備"
	return ""

# 主動作此刻是否可執行（使用類要 can_use；裝備/卸下恆可）。
func _confirm_actionable() -> bool:
	if _confirm_action == "使用":
		return ItemEffects.can_use(ItemCatalog.get_item(String(_confirm_row.get("id", ""))), _selected_member())
	return _confirm_action != ""

func confirm_open() -> bool:
	return _tab == Tab.ITEMS and _mode == Mode.ITEM_CONFIRM

# 可執行 → [動作, 取消]；不可執行（如滿血用治療藥水）→ 只給 [確定]，避免靜默無反應。
func confirm_options() -> Array:
	if _confirm_actionable():
		return [_confirm_action, "取消"]
	return ["確定"]

func _confirm_prompt() -> String:
	var m := _selected_member()
	var nm := String(_confirm_row.get("name", ""))
	match _confirm_action:
		"使用":
			return "對 %s 使用 %s？" % [m.name, nm] if _confirm_actionable() else "%s 現在用不到 %s。" % [m.name, nm]
		"裝備":
			return "讓 %s 裝備 %s？" % [m.name, nm]
		"卸下":
			return "卸下 %s 的 %s？" % [m.name, nm]
	return ""

func _input_item_confirm(key: int) -> void:
	var options := confirm_options()
	var n := options.size()
	match key:
		KEY_ESCAPE:
			_close_confirm()
		KEY_LEFT:
			_confirm_cursor = (_confirm_cursor - 1 + n) % n
			_refresh()
		KEY_RIGHT:
			_confirm_cursor = (_confirm_cursor + 1 + n) % n
			_refresh()
		KEY_ENTER, KEY_KP_ENTER:
			var sel := String(options[clampi(_confirm_cursor, 0, n - 1)])
			if sel == "取消" or sel == "確定":
				_close_confirm()
			else:
				_perform_confirm_action()

func _perform_confirm_action() -> void:
	var events := CharacterItemsTab.activate(_confirm_row, _selected_member(), _state.inventory)
	for e in events:
		_push(String(e))
	_close_confirm()

func _close_confirm() -> void:
	_mode = Mode.LIST
	_confirm_row = {}
	_confirm_action = ""
	_confirm_cursor = 0
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
	var is_items := _tab == Tab.ITEMS
	_status_view.visible = is_status
	_items_view.visible = is_items
	_list_text.visible = not is_status and not is_items
	if is_status:
		_status_view.refresh(_selected_member())
	elif is_items:
		_items_view.refresh(_item_rows(), _item_index())
	else:
		_apply_list_text()
	var show_confirm := is_items and _mode == Mode.ITEM_CONFIRM
	_confirm_dialog.visible = show_confirm
	if show_confirm:
		_confirm_dialog.setup(String(_confirm_row.get("name", "")), _confirm_prompt(), confirm_options(), _confirm_cursor)
	_footer.text = _footer_text()

func _rebuild_tabbar() -> void:
	for c in _tabbar.get_children():
		c.queue_free()
		_tabbar.remove_child(c)
	var names := ["狀態 (C)", "道具 (I)", "法術 (M)"]
	for i in names.size():
		var t := Label.new()
		t.text = names[i]
		t.add_theme_stylebox_override("normal", PanelSkin.tab_stylebox(i == _tab))
		t.add_theme_color_override("font_color", Color(0.95, 0.90, 0.77) if i == _tab else PanelSkin.SECTION)
		t.add_theme_font_size_override("font_size", PanelSkin.FONT_TAB)
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
	var rows := _item_rows()
	var eq := _equip_n(rows)
	var bag := rows.size() - eq
	if bag <= 0:
		_item_zone = 0
		_bag_cursor = 0
	else:
		_bag_cursor = clampi(_bag_cursor, 0, bag - 1)
	_equip_cursor = clampi(_equip_cursor, 0, maxi(0, eq - 1))
	var ns := CharacterSpellsTab.rows(_selected_member()).size()
	if _spell_cursor >= ns:
		_spell_cursor = maxi(0, ns - 1)

func _body_lines() -> Array:
	match _tab:
		Tab.STATUS:
			return CharacterStatusTab.lines(_selected_member())
		Tab.ITEMS:
			return CharacterItemsTab.lines(_item_rows(), _item_index())
		Tab.SPELLS:
			if _mode == Mode.PICK_TARGET:
				return _pick_target_lines()
			return CharacterSpellsTab.lines(CharacterSpellsTab.rows(_selected_member()), _spell_cursor)
	return []

func _footer_text() -> String:
	match _tab:
		Tab.STATUS:
			return "[←→/Tab]分頁  [1-6]換隊員  [Esc]關閉"
		Tab.ITEMS:
			if _mode == Mode.ITEM_CONFIRM:
				return "[←→]選擇  [Enter]確定  [Esc]取消"
			return "[←→]裝備/背包  [Tab]分頁  [1-6]換隊員  [↑↓]選擇  [Enter]使用/裝備/卸下  [Esc]關閉"
		Tab.SPELLS:
			if _mode == Mode.PICK_TARGET:
				return "[↑↓]選對象  [Enter]確定  [Esc]返回"
			return "[←→/Tab]分頁  [1-6]換隊員  [↑↓]選擇  [Enter]施放  [Esc]關閉"
	return ""

func _pick_target_lines() -> Array:
	var out: Array = ["選擇對象（%s）：" % _pending_spell.display_name]
	var ms := _members()
	for i in ms.size():
		var m: Character = ms[i]
		var mark := "> " if i == _target_cursor else "  "
		out.append("%s%s  Lv%d  HP%d/%d" % [mark, m.name, m.level, m.hp, m.hp_max])
	return out
