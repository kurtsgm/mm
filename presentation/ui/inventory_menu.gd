class_name InventoryMenu
extends CanvasLayer

# 程式建構的背包/裝備選單（無真美術），鍵盤操作：
# [↑/↓] 選角色 / [←/→] 選背包道具 / [E] 裝備 / [U] 使用 / [1/2/3] 卸下武器/防具/飾品 / [Esc] 關閉
# 透過 ItemCatalog 把背包 id 解析成 ItemDef；裝備改 Character.equipment，使用走 ItemEffects。
# 不呼叫 set_input_as_handled：開啟期間 main 只看 I/Tab、player 已停用，無按鍵衝突。

signal closed

var _panel: Label
var _member_idx := 0
var _item_idx := 0

func is_open() -> bool:
	return visible

func open() -> void:
	visible = true
	_member_idx = 0
	_item_idx = 0
	set_process_unhandled_input(true)
	_refresh()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	closed.emit()

func _ready() -> void:
	layer = 10
	visible = false
	_panel = Label.new()
	_panel.position = Vector2(60, 60)
	_panel.add_theme_font_size_override("font_size", 16)
	add_child(_panel)
	set_process_unhandled_input(false)

func _members() -> Array:
	return GameState.party.members

func _stacks() -> Array:
	return GameState.inventory.stacks()

func _selected_member() -> Character:
	var ms := _members()
	if _member_idx < 0 or _member_idx >= ms.size():
		return null
	return ms[_member_idx]

func _selected_item() -> ItemDef:
	var st := _stacks()
	if _item_idx < 0 or _item_idx >= st.size():
		return null
	return ItemCatalog.get_item(String(st[_item_idx]["id"]))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		close()
	elif key == KEY_UP:
		var n := _members().size()
		if n > 0:
			_member_idx = (_member_idx + n - 1) % n
		_refresh()
	elif key == KEY_DOWN:
		var n := _members().size()
		if n > 0:
			_member_idx = (_member_idx + 1) % n
		_refresh()
	elif key == KEY_LEFT:
		var n := _stacks().size()
		if n > 0:
			_item_idx = (_item_idx + n - 1) % n
		_refresh()
	elif key == KEY_RIGHT:
		var n := _stacks().size()
		if n > 0:
			_item_idx = (_item_idx + 1) % n
		_refresh()
	elif key == KEY_E:
		_equip_selected()
	elif key == KEY_U:
		_use_selected()
	elif key == KEY_1:
		_unequip(Equipment.Slot.WEAPON)
	elif key == KEY_2:
		_unequip(Equipment.Slot.ARMOR)
	elif key == KEY_3:
		_unequip(Equipment.Slot.ACCESSORY)

func _equip_selected() -> void:
	var member := _selected_member()
	var item := _selected_item()
	if member == null or item == null or not member.equipment.can_equip(item):
		return
	var displaced := member.equipment.equip(item)
	GameState.inventory.remove(item.id, 1)
	if displaced != null:
		GameState.inventory.add(displaced.id, 1)
	GameState.message_log.push("%s 裝備了 %s。" % [member.name, item.display_name])
	_clamp_item_idx()
	_refresh()

func _use_selected() -> void:
	var member := _selected_member()
	var item := _selected_item()
	if member == null or item == null:
		return
	var events := ItemEffects.apply(item, member)
	if events.is_empty():
		return
	GameState.inventory.remove(item.id, 1)
	for e in events:
		GameState.message_log.push(e)
	_clamp_item_idx()
	_refresh()

func _unequip(slot: int) -> void:
	var member := _selected_member()
	if member == null:
		return
	var removed := member.equipment.unequip(slot)
	if removed != null:
		GameState.inventory.add(removed.id, 1)
		GameState.message_log.push("%s 卸下了 %s。" % [member.name, removed.display_name])
	_refresh()

func _clamp_item_idx() -> void:
	var n := _stacks().size()
	if _item_idx >= n:
		_item_idx = maxi(0, n - 1)

func _refresh() -> void:
	var lines: Array[String] = ["== 背包/裝備 ==  [↑↓]角色 [←→]道具 [E]裝備 [U]使用 [1/2/3]卸裝 [Esc]關"]
	var ms := _members()
	for i in ms.size():
		var c: Character = ms[i]
		var marker := "> " if i == _member_idx else "  "
		lines.append("%s%s Lv%d HP%d/%d SP%d/%d  武:%s 防:%s 飾:%s" % [
			marker, c.name, c.level, c.hp, c.hp_max, c.sp, c.sp_max,
			_slot_name(c, Equipment.Slot.WEAPON),
			_slot_name(c, Equipment.Slot.ARMOR),
			_slot_name(c, Equipment.Slot.ACCESSORY)])
	lines.append("-- 背包 --")
	var st := _stacks()
	if st.is_empty():
		lines.append("（空）")
	else:
		var parts: Array[String] = []
		for i in st.size():
			var item := ItemCatalog.get_item(String(st[i]["id"]))
			var nm := item.display_name if item != null else String(st[i]["id"])
			var sel := ">" if i == _item_idx else " "
			parts.append("%s%s×%d" % [sel, nm, int(st[i]["count"])])
		lines.append("  ".join(parts))
	_panel.text = "\n".join(lines)

func _slot_name(c: Character, slot: int) -> String:
	var item := c.equipment.get_item(slot)
	return item.display_name if item != null else "-"
