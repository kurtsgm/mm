class_name MiniMap
extends CanvasLayer
# 右上角常駐俯視小地圖（迷霧探索）。程式建構 placeholder UI，鏡射 Hud。
# 每格一色塊：已探索才畫（未探索露出底板＝迷霧）；玩家為朝向三角形。
# 資料來源：MapManager.current_map（tile/portal）、GameState（explored/pos/facing）。

const CELL_PX := 16
const PAD := 6
const BORDER := 1.0
const MARGIN := 12  # 離畫面右上角

const COL_BACKDROP := Color(0, 0, 0, 0.55)
const COL_BORDER := Color(1, 1, 1, 0.35)
const COL_FLOOR := Color(0.72, 0.72, 0.72)
const COL_WALL := Color(0.16, 0.16, 0.18)
const COL_DOOR := Color(0.78, 0.6, 0.28)
const COL_STAIRS_UP := Color(0.5, 0.72, 0.95)
const COL_STAIRS_DOWN := Color(0.66, 0.46, 0.85)
const COL_PORTAL := Color(0.36, 0.82, 0.46)
const COL_PLAYER := Color(0.95, 0.3, 0.3)

var _panel: Control

func setup(player: PlayerController) -> void:
	_panel = _MiniMapPanel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	player.entered_cell.connect(func(_p): _panel.queue_redraw())
	player.facing_changed.connect(func(_f): _panel.queue_redraw())
	refresh()

# 依當前地圖尺寸把面板釘在右上角並重畫。切圖/讀檔後由 main 呼叫。
func refresh() -> void:
	if _panel == null:
		return
	var map := MapManager.current_map
	var w: int = map.width if map != null else 0
	var h: int = map.height if map != null else 0
	var pw: float = w * CELL_PX + PAD * 2
	var ph: float = h * CELL_PX + PAD * 2
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_top = MARGIN
	_panel.offset_bottom = MARGIN + ph
	_panel.offset_right = -MARGIN
	_panel.offset_left = -MARGIN - pw
	_panel.queue_redraw()

# tile type + 是否 portal → 色塊顏色（portal 旗標優先）。純函式、可測。
static func tile_color(tile: int, is_portal: bool) -> Color:
	if is_portal:
		return COL_PORTAL
	match tile:
		MapData.TileType.WALL: return COL_WALL
		MapData.TileType.DOOR: return COL_DOOR
		MapData.TileType.STAIRS_UP: return COL_STAIRS_UP
		MapData.TileType.STAIRS_DOWN: return COL_STAIRS_DOWN
		_: return COL_FLOOR

# 內部繪製面板。_draw 在 CanvasItem(Control) 上，讀 autoload；與 MiniMap 拆開。
class _MiniMapPanel extends Control:
	func _draw() -> void:
		var map = MapManager.current_map
		if map == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), MiniMap.COL_BACKDROP, true)
		draw_rect(Rect2(Vector2.ZERO, size), MiniMap.COL_BORDER, false, MiniMap.BORDER)
		var explored: Dictionary = GameState.explored_for(map.map_id)
		for y in map.height:
			for x in map.width:
				var cell := Vector2i(x, y)
				if not explored.has(cell):
					continue
				var col := MiniMap.tile_color(map.get_tile(cell), map.has_link(cell))
				var r := Rect2(
					MiniMap.PAD + x * MiniMap.CELL_PX,
					MiniMap.PAD + y * MiniMap.CELL_PX,
					MiniMap.CELL_PX - 1, MiniMap.CELL_PX - 1)
				draw_rect(r, col, true)
		_draw_player()

	func _draw_player() -> void:
		var pos: Vector2i = GameState.player_pos
		var c := Vector2(
			MiniMap.PAD + pos.x * MiniMap.CELL_PX + MiniMap.CELL_PX * 0.5,
			MiniMap.PAD + pos.y * MiniMap.CELL_PX + MiniMap.CELL_PX * 0.5)
		var r: float = MiniMap.CELL_PX * 0.42
		var fwd := _facing_vec(GameState.player_facing)
		var side := Vector2(-fwd.y, fwd.x)
		var tip := c + fwd * r
		var bl := c - fwd * r + side * (r * 0.7)
		var br := c - fwd * r - side * (r * 0.7)
		draw_colored_polygon(PackedVector2Array([tip, bl, br]), MiniMap.COL_PLAYER)

	func _facing_vec(facing: int) -> Vector2:
		match facing:
			GridDirection.Dir.EAST: return Vector2(1, 0)
			GridDirection.Dir.SOUTH: return Vector2(0, 1)
			GridDirection.Dir.WEST: return Vector2(-1, 0)
		return Vector2(0, -1)  # NORTH（含預設）：螢幕上方
