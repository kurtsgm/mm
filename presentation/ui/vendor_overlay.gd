class_name VendorOverlay
extends CanvasLayer
# 比例式商店覆蓋層。kind=goods：[Tab]切買/賣 [↑↓]選 [Enter]成交 [Esc]關。
# 交易走 VendorTransaction（ctx=傳入 state）；事件以 transacted 訊號交給 main 推訊息列。
# 不直接碰 message_log。

signal transacted(events: Array)
signal finished

var _vendor: Dictionary = {}
var _state                      # GameState 或測試假物件（需 gold/inventory/party.members）
var _panel: Label
var _cursor: int = 0
var _buy_mode: bool = true      # goods：true=買 false=賣

enum Mode { LIST = 0, PICK_TARGET = 1 }
var _mode: int = Mode.LIST
var _pending: Dictionary = {}   # 待確認的 spell/offer（進 PICK_TARGET 時暫存）
var _tcursor: int = 0           # 選角色游標

func is_open() -> bool:
	return visible

func _ready() -> void:
	layer = 11
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := Panel.new()
	# 置中區塊：左右各留 15%、上下各留 12%。
	box.anchor_left = 0.15
	box.anchor_right = 0.85
	box.anchor_top = 0.12
	box.anchor_bottom = 0.88
	add_child(box)
	_panel = Label.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 20
	_panel.offset_top = 16
	_panel.offset_right = -20
	_panel.offset_bottom = -16
	_panel.add_theme_font_size_override("font_size", 18)
	box.add_child(_panel)
	set_process_unhandled_input(false)

func open(vendor: Dictionary, state) -> void:
	_vendor = vendor
	_state = state
	_cursor = 0
	_buy_mode = true
	_mode = Mode.LIST
	_pending = {}
	_tcursor = 0
	visible = true
	set_process_unhandled_input(true)
	_render()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)

# --- goods 清單來源 ---
func _goods_rows() -> Array:
	# 回 [{id, name, price}]；買=stock，賣=背包現有可賣物。
	var rows: Array = []
	if _buy_mode:
		for id in _vendor.get("stock", []):
			var item := ItemCatalog.get_item(String(id))
			if item == null:
				continue
			rows.append({"id": item.id, "name": item.display_name, "price": item.value})
	else:
		var factor := float(_vendor.get("sell_factor", 0.5))
		for s in _state.inventory.stacks():
			var item := ItemCatalog.get_item(String(s["id"]))
			if item == null:
				continue
			rows.append({"id": item.id, "name": item.display_name,
						 "price": int(floor(item.value * factor)), "count": int(s["count"])})
	return rows

func _render() -> void:
	match String(_vendor.get("kind", "")):
		"goods":
			_render_goods()
		"spells":
			_render_spells()
		"services":
			_render_services()
		_:
			_panel.text = "（不支援的商店類型）"

func _render_goods() -> void:
	var lines: Array = []
	lines.append("== %s ==   金幣：%d" % [String(_vendor.get("name", "商店")), int(_state.gold)])
	if _vendor.has("greeting"):
		lines.append(String(_vendor["greeting"]))
	lines.append("[%s] 買    [%s] 賣      [Tab]切換 [↑↓]選 [Enter]成交 [Esc]離開" %
		["X" if _buy_mode else " ", " " if _buy_mode else "X"])
	lines.append("--")
	var rows := _goods_rows()
	if rows.is_empty():
		lines.append("（沒有可%s的東西）" % ("購買" if _buy_mode else "出售"))
	for i in rows.size():
		var mark := "> " if i == _cursor else "  "
		var afford := "" if (not _buy_mode or int(_state.gold) >= int(rows[i]["price"])) else "（金幣不足）"
		var cnt := ("×%d" % int(rows[i]["count"])) if rows[i].has("count") else ""
		lines.append("%s%s%s  %d 金 %s" % [mark, String(rows[i]["name"]), cnt, int(rows[i]["price"]), afford])
	_panel.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match String(_vendor.get("kind", "")):
		"goods":
			_input_goods(event)
		"spells":
			_input_list_kind(event, "spells")
		"services":
			_input_list_kind(event, "services")

func _input_goods(event: InputEventKey) -> void:
	var rows := _goods_rows()
	match event.keycode:
		KEY_ESCAPE:
			close()
			finished.emit()
		KEY_TAB:
			_buy_mode = not _buy_mode
			_cursor = 0
			_render()
		KEY_UP:
			if rows.size() > 0:
				_cursor = (_cursor - 1 + rows.size()) % rows.size()
				_render()
		KEY_DOWN:
			if rows.size() > 0:
				_cursor = (_cursor + 1) % rows.size()
				_render()
		KEY_ENTER:
			if _cursor < 0 or _cursor >= rows.size():
				return
			var id := String(rows[_cursor]["id"])
			var item := ItemCatalog.get_item(id)
			if item == null:
				return
			var res: Dictionary
			if _buy_mode:
				res = VendorTransaction.buy_goods(_state, item)
			else:
				res = VendorTransaction.sell_goods(_state, item, float(_vendor.get("sell_factor", 0.5)))
			if res["ok"]:
				transacted.emit(res["events"])
			# 賣到清單變短時夾住游標
			var n := _goods_rows().size()
			if _cursor >= n:
				_cursor = maxi(n - 1, 0)
			_render()

# --- spells/services 清單來源 ---
func _spell_rows() -> Array:
	var rows: Array = []
	for id in _vendor.get("spells", []):
		var sp := SpellBook.get_spell(String(id))
		if sp == null:
			continue
		rows.append({"id": sp.id, "name": sp.display_name, "price": sp.gold_cost,
					 "school": sp.school})
	return rows

func _offer_rows() -> Array:
	var rows: Array = []
	for o in _vendor.get("offers", []):
		rows.append(o)
	return rows

# 某法術/服務的合格對象（回 [{idx, member, ok, reason}]，ok=false 仍列出但標因/灰）。
func _targets_for(pending: Dictionary, kind: String) -> Array:
	var out: Array = []
	var members: Array = _state.party.members
	for i in members.size():
		var m = members[i]
		var ok := true
		var reason := ""
		if kind == "spells":
			var sp := SpellBook.get_spell(String(pending["id"]))
			var e: Dictionary = SpellEligibility.can_learn(m, sp)
			ok = e["ok"]
			reason = e["reason"]
		else:
			match String(pending.get("effect", "")):
				"revive":
					ok = (m.condition != Character.Condition.OK)
					reason = "" if ok else "無需復活"
				"heal_full":
					ok = (m.condition != Character.Condition.DEAD and (m.hp < m.hp_max or m.condition == Character.Condition.UNCONSCIOUS))
					reason = "" if ok else "已滿/無法治療"
		out.append({"idx": i, "member": m, "ok": ok, "reason": reason})
	return out

# targets 陣列中第一個合格者的索引；全不合格回 0（ENTER 仍會被 ok 檢查擋下）。
func _first_eligible(targets: Array) -> int:
	for i in targets.size():
		if targets[i]["ok"]:
			return i
	return 0

func _render_header(lines: Array) -> void:
	lines.append("== %s ==   金幣：%d" % [String(_vendor.get("name", "商店")), int(_state.gold)])
	if _vendor.has("greeting"):
		lines.append(String(_vendor["greeting"]))
	lines.append("--")

func _render_spells() -> void:
	var lines: Array = []
	_render_header(lines)
	if _mode == Mode.PICK_TARGET:
		_render_pick(lines, "spells")
	else:
		lines.append("[↑↓]選法術 [Enter]選擇對象 [Esc]離開")
		var rows := _spell_rows()
		for i in rows.size():
			var mark := "> " if i == _cursor else "  "
			var sch := "祕法" if int(rows[i]["school"]) == SpellDef.School.ARCANE else "神聖"
			lines.append("%s%s（%s）  %d 金" % [mark, String(rows[i]["name"]), sch, int(rows[i]["price"])])
	_panel.text = "\n".join(lines)

func _render_services() -> void:
	var lines: Array = []
	_render_header(lines)
	if _mode == Mode.PICK_TARGET:
		_render_pick(lines, "services")
	else:
		lines.append("[↑↓]選服務 [Enter]選擇 [Esc]離開")
		var rows := _offer_rows()
		for i in rows.size():
			var mark := "> " if i == _cursor else "  "
			lines.append("%s%s  %d 金" % [mark, String(rows[i]["name"]), int(rows[i].get("cost", 0))])
	_panel.text = "\n".join(lines)

func _render_pick(lines: Array, kind: String) -> void:
	lines.append("選擇對象：[↑↓]選 [Enter]確定 [Esc]返回")
	var ts := _targets_for(_pending, kind)
	for i in ts.size():
		var mark := "> " if i == _tcursor else "  "
		var m = ts[i]["member"]
		var tag := "" if ts[i]["ok"] else ("（%s）" % String(ts[i]["reason"]))
		lines.append("%s%s %s Lv%d HP%d/%d%s" % [mark, m.name, m.char_class, m.level, m.hp, m.hp_max, tag])

# spells/services 共用輸入（LIST 與 PICK_TARGET 兩態）。
func _input_list_kind(event: InputEventKey, kind: String) -> void:
	var rows := _spell_rows() if kind == "spells" else _offer_rows()
	if _mode == Mode.LIST:
		match event.keycode:
			KEY_ESCAPE:
				close()
				finished.emit()
			KEY_UP:
				if rows.size() > 0:
					_cursor = (_cursor - 1 + rows.size()) % rows.size()
					_render()
			KEY_DOWN:
				if rows.size() > 0:
					_cursor = (_cursor + 1) % rows.size()
					_render()
			KEY_ENTER:
				if _cursor < 0 or _cursor >= rows.size():
					return
				var sel: Dictionary = rows[_cursor]
				if kind == "services" and String(sel.get("target", "character")) == "party":
					_commit(kind, sel, _state.party.members)        # 全隊：直接套
				else:
					_pending = sel
					_tcursor = _first_eligible(_targets_for(sel, kind))   # 游標落在第一個合格對象
					_mode = Mode.PICK_TARGET
					_render()
	else:  # PICK_TARGET
		var ts := _targets_for(_pending, kind)
		match event.keycode:
			KEY_ESCAPE:
				_mode = Mode.LIST
				_render()
			KEY_UP:
				if ts.size() > 0:
					_tcursor = (_tcursor - 1 + ts.size()) % ts.size()
					_render()
			KEY_DOWN:
				if ts.size() > 0:
					_tcursor = (_tcursor + 1) % ts.size()
					_render()
			KEY_ENTER:
				if _tcursor < 0 or _tcursor >= ts.size() or not ts[_tcursor]["ok"]:
					return
				_commit(kind, _pending, [ts[_tcursor]["member"]])
				_mode = Mode.LIST
				_render()

func _commit(kind: String, sel: Dictionary, targets: Array) -> void:
	var res: Dictionary
	if kind == "spells":
		res = VendorTransaction.learn_spell(_state, SpellBook.get_spell(String(sel["id"])), targets[0])
	else:
		res = VendorTransaction.buy_service(_state, sel, targets)
	if res["ok"]:
		transacted.emit(res["events"])
