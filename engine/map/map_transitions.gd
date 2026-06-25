class_name MapTransitions
extends Object

# 自 move_dir 走出 map 邊緣（目標出界）且該向有鄰圖 → 邊緣切換事件。
static func edge_exit(map: MapData, pos: Vector2i, move_dir: int) -> Dictionary:
	var target := pos + GridDirection.to_vector(move_dir)
	if target.x >= 0 and target.x < map.width and target.y >= 0 and target.y < map.height:
		return {}  # 仍在界內 → 非邊緣事件
	if not map.has_neighbor(move_dir):
		return {}
	var lateral: int
	if move_dir == GridDirection.Dir.EAST or move_dir == GridDirection.Dir.WEST:
		lateral = pos.y  # 東西向移動 → 保留 y
	else:
		lateral = pos.x  # 南北向移動 → 保留 x
	return { "neighbor_id": map.get_neighbor(move_dir), "edge_dir": move_dir, "lateral": lateral }

# 自 edge_dir 離開來源 → 進 dest 的「對邊」、同側 lateral 格。
# lateral 出界或對邊格實心 → Vector2i(-1, -1)（擋住）。
static func arrival_cell(dest_map: MapData, edge_dir: int, lateral: int) -> Vector2i:
	var cell: Vector2i
	match edge_dir:
		GridDirection.Dir.EAST: cell = Vector2i(0, lateral)
		GridDirection.Dir.WEST: cell = Vector2i(dest_map.width - 1, lateral)
		GridDirection.Dir.SOUTH: cell = Vector2i(lateral, 0)
		GridDirection.Dir.NORTH: cell = Vector2i(lateral, dest_map.height - 1)
		_: return Vector2i(-1, -1)
	if cell.x < 0 or cell.x >= dest_map.width or cell.y < 0 or cell.y >= dest_map.height:
		return Vector2i(-1, -1)
	if not MapBuilder.is_walkable_type(dest_map.get_tile(cell)):
		return Vector2i(-1, -1)
	return cell

static func resolve_link(map: MapData, pos: Vector2i) -> Dictionary:
	if map.has_link(pos):
		return map.get_link(pos)
	return {}
