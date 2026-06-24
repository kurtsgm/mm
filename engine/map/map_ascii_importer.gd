class_name MapAsciiImporter
extends Object

# 合法 → MapData；任何違規 → null（不做 log 副作用）。
static func parse(text: String) -> MapData:
	var lines := _to_lines(text)
	if lines.is_empty():
		return null
	var height := lines.size()
	var width: int = lines[0].length()
	if width == 0:
		return null
	var tiles := PackedInt32Array()
	tiles.resize(width * height)
	var start_pos := Vector2i(-1, -1)
	for y in height:
		var line: String = lines[y]
		if line.length() != width:
			return null  # 非矩形
		for x in width:
			var ch := line[x]
			var t := _char_to_tile(ch)
			if t == -1:
				return null  # 未知字元
			if ch == "@":
				if start_pos != Vector2i(-1, -1):
					return null  # 多個起點
				start_pos = Vector2i(x, y)
			tiles[y * width + x] = t
	if start_pos == Vector2i(-1, -1):
		return null  # 沒有起點
	var map := MapData.new()
	map.width = width
	map.height = height
	map.tiles = tiles
	map.start_pos = start_pos
	map.start_facing = GridDirection.Dir.NORTH
	return map

# 切行、修掉每行行尾空白（含 \r）、丟掉開頭與結尾的空行。
static func _to_lines(text: String) -> Array:
	var out: Array = []
	for p in text.split("\n"):
		out.append(p.strip_edges(false, true))  # 只修右側（行尾）
	while out.size() > 0 and out[0] == "":
		out.remove_at(0)
	while out.size() > 0 and out[out.size() - 1] == "":
		out.remove_at(out.size() - 1)
	return out

static func _char_to_tile(ch: String) -> int:
	match ch:
		"#": return MapData.TileType.WALL
		".": return MapData.TileType.FLOOR
		"@": return MapData.TileType.FLOOR  # 起點格是地板
		"D": return MapData.TileType.DOOR
		"<": return MapData.TileType.STAIRS_UP
		">": return MapData.TileType.STAIRS_DOWN
		_: return -1
