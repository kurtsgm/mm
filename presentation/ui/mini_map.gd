class_name MiniMap
extends CanvasLayer
# 右上角常駐俯視小地圖（以隊伍為中心 + 鄰圖拼裝 + 迷霧探索）。程式建構 UI，鏡射 Hud。
# 視窗 (2*RADIUS+1)² 格、隊伍恆置中、地圖捲動；觸及邊界拼進相鄰地圖（含對角）。
# 每張圖各套自己的 explored 迷霧。資料：MapManager.current_map/peek_map、GameState。

const RADIUS := 6        # 以隊伍為中心、每側可見格數（視窗 13×13）
const CELL_PX := 22
const PAD := 6
const BORDER := 1.0
const MARGIN := 12       # 離畫面右上角

const COL_BACKDROP := Color(0, 0, 0, 0.55)
const COL_BORDER := Color(1, 1, 1, 0.35)
const COL_FLOOR := Color(0.72, 0.72, 0.72)
const COL_WALL := Color(0.16, 0.16, 0.18)
const COL_DOOR := Color(0.78, 0.6, 0.28)
const COL_STAIRS_UP := Color(0.5, 0.72, 0.95)
const COL_STAIRS_DOWN := Color(0.66, 0.46, 0.85)
const COL_PORTAL := Color(0.36, 0.82, 0.46)
const COL_PLAYER := Color(0.95, 0.3, 0.3)

var _panel                       # _MiniMapPanel（untyped 以容許動態 .loader 屬性）
var _map_cache: Dictionary = {}  # id -> MapData（會快取 null，避免重試不存在的檔）

func setup(player: PlayerController) -> void:
	_panel = _MiniMapPanel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.loader = Callable(self, "_peek_cached")
	add_child(_panel)
	player.entered_cell.connect(func(_p): _panel.queue_redraw())
	player.facing_changed.connect(func(_f): _panel.queue_redraw())
	refresh()

# 切圖/讀檔後由 main 呼叫：清鄰圖快取（鄰里換了）+ 重設固定面板大小（右上角）+ 重畫。
func refresh() -> void:
	if _panel == null:
		return
	_map_cache.clear()
	var side := panel_side()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_top = MARGIN
	_panel.offset_bottom = MARGIN + side
	_panel.offset_right = -MARGIN
	_panel.offset_left = -MARGIN - side
	_panel.queue_redraw()

# 無副作用載入鄰圖並快取（含 null）。供 WorldStitch 的 loader 用。
func _peek_cached(id: String) -> MapData:
	if not _map_cache.has(id):
		_map_cache[id] = MapManager.peek_map(id)
	return _map_cache[id]

# 面板邊長（含 pad）。純、可測。
static func panel_side() -> float:
	return (2 * RADIUS + 1) * CELL_PX + PAD * 2

# 全域格 → 面板像素左上角（隊伍 center 恆落在視窗正中）。純、可測。
static func cell_top_left(global: Vector2i, center: Vector2i) -> Vector2:
	return Vector2(
		PAD + (global.x - (center.x - RADIUS)) * CELL_PX,
		PAD + (global.y - (center.y - RADIUS)) * CELL_PX)

# tile type + 是否 portal → 色塊顏色（portal 旗標優先）。純、可測。
static func tile_color(tile: int, is_portal: bool) -> Color:
	if is_portal:
		return COL_PORTAL
	match tile:
		MapData.TileType.WALL: return COL_WALL
		MapData.TileType.DOOR: return COL_DOOR
		MapData.TileType.STAIRS_UP: return COL_STAIRS_UP
		MapData.TileType.STAIRS_DOWN: return COL_STAIRS_DOWN
		_: return COL_FLOOR

# 內部繪製面板。_draw 在 CanvasItem(Control) 上，讀 autoload + 注入的 loader。
class _MiniMapPanel extends Control:
	var loader: Callable

	func _draw() -> void:
		var map = MapManager.current_map
		if map == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), MiniMap.COL_BACKDROP, true)
		draw_rect(Rect2(Vector2.ZERO, size), MiniMap.COL_BORDER, false, MiniMap.BORDER)
		var center: Vector2i = GameState.player_pos
		var r: int = MiniMap.RADIUS
		var csz: float = MiniMap.CELL_PX - 1
		var placed := WorldStitch.place(map, loader, r, center)
		for node in placed:
			var pm: MapData = node["map"]
			var ox: int = node["ox"]
			var oy: int = node["oy"]
			var explored: Dictionary = GameState.explored_for(pm.map_id)
			for cy in pm.height:
				for cx in pm.width:
					var cell := Vector2i(cx, cy)
					if not explored.has(cell):
						continue
					var gx := ox + cx
					var gy := oy + cy
					if gx < center.x - r or gx > center.x + r or gy < center.y - r or gy > center.y + r:
						continue
					var tl := MiniMap.cell_top_left(Vector2i(gx, gy), center)
					var col := MiniMap.tile_color(pm.get_tile(cell), pm.has_link(cell))
					draw_rect(Rect2(tl.x, tl.y, csz, csz), col, true)
		_draw_player(center)

	func _draw_player(center: Vector2i) -> void:
		var tl := MiniMap.cell_top_left(center, center)
		var c := tl + Vector2(MiniMap.CELL_PX * 0.5, MiniMap.CELL_PX * 0.5)
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
