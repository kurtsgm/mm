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
