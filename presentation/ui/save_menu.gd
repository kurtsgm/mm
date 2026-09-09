class_name SaveMenu
extends CanvasLayer

# 程式建構的存讀檔選單（無真美術）：列出 SLOT_COUNT 槽，鍵盤操作。
# [↑/↓ 或 1-5] 選槽 / [S] 存檔 / [L] 讀檔 / [X] 刪除（需 Y 確認）/ [Esc] 關閉
# 直接驅動 SaveSystem；讀檔成功後關閉，世界重建由 main 接 SaveSystem.loaded。
# Tab 交給 main 切換選單，其餘按鍵由本選單消耗。

signal closed

var _panel: Label
var _selected := 0
var _confirm_delete := false
var _can_save := true

func is_open() -> bool:
	return visible

func open(can_save: bool = true) -> void:
	_can_save = can_save
	visible = true
	_selected = 0
	_confirm_delete = false
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
	_panel.anchor_left = 0.05
	_panel.anchor_top = 0.08
	_panel.anchor_right = 0.95
	_panel.anchor_bottom = 0.92
	_panel.add_theme_font_size_override("font_size", 18)
	add_child(_panel)
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	if key != KEY_TAB:
		get_viewport().set_input_as_handled()
	if _confirm_delete:
		if key == KEY_Y:
			SaveSystem.delete_slot(_selected)
		_confirm_delete = false
		_refresh()
		return
	if key == KEY_ESCAPE:
		close()
	elif key == KEY_UP:
		_selected = (_selected + SaveSystem.SLOT_COUNT - 1) % SaveSystem.SLOT_COUNT
		_refresh()
	elif key == KEY_DOWN:
		_selected = (_selected + 1) % SaveSystem.SLOT_COUNT
		_refresh()
	elif key >= KEY_1 and key <= KEY_5:
		var idx := key - KEY_1
		if idx < SaveSystem.SLOT_COUNT:
			_selected = idx
			_refresh()
	elif key == KEY_S and _can_save:
		SaveSystem.save_to_slot(_selected)
		GameState.message_log.push("已存檔到第 %d 槽。" % (_selected + 1))
		_refresh()
	elif key == KEY_L:
		if SaveSystem.has_slot(_selected):
			SaveSystem.load_from_slot(_selected)
			GameState.message_log.push("已讀取第 %d 槽。" % (_selected + 1))
			close()
	elif key == KEY_X:
		if SaveSystem.has_slot(_selected):
			_confirm_delete = true
			_refresh()

func _refresh() -> void:
	var save_hint := "[S]存 " if _can_save else ""
	var lines: Array[String] = ["== 存讀檔 ==  [↑↓/1-5]選 %s[L]讀 [X]刪 [Esc]關" % save_hint]
	var slots := SaveSystem.list_slots()
	for i in slots.size():
		var marker := "> " if i == _selected else "  "
		var meta: Dictionary = slots[i]
		var desc := "（空）"
		if not meta.is_empty():
			desc = "%s  金幣%d  %s" % [
				meta.get("map_id", "?"), int(meta.get("gold", 0)), meta.get("saved_at", "")]
		lines.append("%s第%d槽：%s" % [marker, i + 1, desc])
	if _confirm_delete:
		lines.append("確認刪除第 %d 槽？[Y] 確認 / 其他鍵取消" % (_selected + 1))
	_panel.text = "\n".join(lines)
