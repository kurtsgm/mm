class_name WorldMapScreen
extends CanvasLayer
# M 鍵開關的世界地圖總覽：六大陸比例佈局＋目前位置＋已解鎖旅行節點。
# 開關介面（is_open/open/close＋closed）與 QuestLog 相同，掛進 main._toggle_menu。
# 版面全部比例式（anchor／size 比例），解析度無關。

signal closed

var _canvas: _MapCanvas

func _ready() -> void:
	layer = 10
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_canvas = _MapCanvas.new()
	_canvas.anchor_left = 0.08
	_canvas.anchor_right = 0.92
	_canvas.anchor_top = 0.08
	_canvas.anchor_bottom = 0.92
	add_child(_canvas)
	set_process_unhandled_input(false)

func is_open() -> bool:
	return visible

func open() -> void:
	_canvas.current_continent = MapManager.current_map.continent if MapManager.current_map else ""
	_canvas.unlocked_nodes = TravelCatalog.unlocked_destinations(GameState, "")
	visible = true
	set_process_unhandled_input(true)
	_canvas.queue_redraw()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

class _MapCanvas:
	extends Control

	const SEA := Color(0.13, 0.17, 0.24)
	const LAND := Color(0.45, 0.38, 0.26)
	const LAND_HERE := Color(0.72, 0.58, 0.30)
	const EDGE := Color(0.85, 0.78, 0.60)

	var current_continent := ""
	var unlocked_nodes: Array = []

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), SEA)
		for c in ContinentCatalog.load_all():
			var r: Array = c["rect"]
			var rect := Rect2(size.x * float(r[0]), size.y * float(r[1]), size.x * float(r[2]), size.y * float(r[3]))
			var here: bool = String(c["id"]) == current_continent
			draw_rect(rect, LAND_HERE if here else LAND)
			draw_rect(rect, EDGE, false, 3.0 if here else 1.0)
			var fs := int(size.y * 0.035)
			draw_string(font, rect.position + Vector2(8, fs + 6), String(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, EDGE)
			if here:
				draw_string(font, rect.position + Vector2(8, fs * 2 + 10), "◆ 目前位置", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.7), Color.WHITE)
			# 已解鎖旅行節點：列在該大陸色塊下緣
			var line := 0
			for n in unlocked_nodes:
				if String(n.get("continent", "")) != String(c["id"]):
					continue
				line += 1
				var y := rect.position.y + rect.size.y - 8 - (line - 1) * fs * 0.8
				draw_circle(Vector2(rect.position.x + 10, y - fs * 0.25), 4.0, Color(0.95, 0.85, 0.4))
				draw_string(font, Vector2(rect.position.x + 20, y), String(n["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.65), Color(0.95, 0.9, 0.75))
		var hint_fs := int(size.y * 0.03)
		draw_string(font, Vector2(8, size.y - 8), "M／Esc 關閉", HORIZONTAL_ALIGNMENT_LEFT, -1, hint_fs, EDGE)
