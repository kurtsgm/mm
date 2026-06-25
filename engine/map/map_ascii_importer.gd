class_name MapAsciiImporter
extends Object

# 合法 → MapData；任何違規 → null（不做 log 副作用）。
static func parse(text: String) -> MapData:
	var lines := _to_lines(text)
	if lines.is_empty():
		return null
	var theme_id := "default"
	var display_name := ""
	var neighbors := {}
	var entries := {}
	var link_markers := {}   # String(char) -> { "map": String, "entry": String }
	# 消化開頭的 key: value 指令行（格子行永遠不含 ":"）
	while not lines.is_empty() and _is_directive(lines[0]):
		var directive: String = lines[0]
		lines.remove_at(0)
		var colon := directive.find(":")
		var key := directive.substr(0, colon).strip_edges()
		var value := directive.substr(colon + 1).strip_edges()
		var parts := key.split(" ", false)
		var cmd: String = parts[0] if parts.size() > 0 else ""
		match cmd:
			"theme":
				if value != "":
					theme_id = value
			"name":
				display_name = value
			"north", "east", "south", "west":
				if value != "":
					neighbors[_word_to_dir(cmd)] = value
			"entry":
				if parts.size() >= 2:
					var e := _parse_entry_value(value)
					if not e.is_empty():
						entries[parts[1]] = e
			"link":
				if parts.size() >= 2:
					var l := _parse_link_value(value)
					if not l.is_empty():
						link_markers[parts[1]] = l
			_:
				pass  # 未知指令忽略
	if lines.is_empty():
		return null
	var height := lines.size()
	var width: int = lines[0].length()
	if width == 0:
		return null
	var tiles := PackedInt32Array()
	tiles.resize(width * height)
	var encounters := {}
	var links := {}
	var start_pos := Vector2i(-1, -1)
	for y in height:
		var line: String = lines[y]
		if line.length() != width:
			return null  # 非矩形
		for x in width:
			var ch := line[x]
			var t := _char_to_tile(ch)
			if t == -1:
				if _is_encounter_marker(ch):
					t = MapData.TileType.FLOOR
					encounters[Vector2i(x, y)] = ch
				elif link_markers.has(ch):
					t = MapData.TileType.FLOOR
					links[Vector2i(x, y)] = link_markers[ch]
				else:
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
	map.encounters = encounters
	map.start_pos = start_pos
	map.start_facing = GridDirection.Dir.NORTH
	map.theme_id = theme_id
	entries["start"] = { "pos": start_pos, "facing": GridDirection.Dir.NORTH }
	map.display_name = display_name
	map.neighbors = neighbors
	map.entries = entries
	map.links = links
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

static func _is_encounter_marker(ch: String) -> bool:
	return ch.length() == 1 and ch >= "a" and ch <= "z"

# 指令行 = 含 ":" 的行。合法格子字元（# . @ D < > a-z A-Z）皆不含 ":"，故無歧義。
static func _is_directive(line: String) -> bool:
	return line.find(":") > 0

static func _word_to_dir(word: String) -> int:
	match word:
		"north": return GridDirection.Dir.NORTH
		"east": return GridDirection.Dir.EAST
		"south": return GridDirection.Dir.SOUTH
		"west": return GridDirection.Dir.WEST
		_: return GridDirection.Dir.NORTH

static func _facing_word_to_dir(word: String) -> int:
	match word.to_upper():
		"N": return GridDirection.Dir.NORTH
		"E": return GridDirection.Dir.EAST
		"S": return GridDirection.Dir.SOUTH
		"W": return GridDirection.Dir.WEST
		_: return GridDirection.Dir.NORTH

# "4,9 S" -> {pos: Vector2i(4,9), facing: SOUTH}；facing 省略→NORTH；畸形→{}
static func _parse_entry_value(value: String) -> Dictionary:
	var toks := value.split(" ", false)
	if toks.is_empty():
		return {}
	var coords := toks[0].split(",", false)
	if coords.size() < 2:
		return {}
	if not (coords[0].is_valid_int() and coords[1].is_valid_int()):
		return {}
	var facing := GridDirection.Dir.NORTH
	if toks.size() >= 2:
		facing = _facing_word_to_dir(toks[1])
	return { "pos": Vector2i(int(coords[0]), int(coords[1])), "facing": facing }

# "town_oak.gate" -> {map:"town_oak", entry:"gate"}；"town_oak" -> entry "start"；空 → {}
static func _parse_link_value(value: String) -> Dictionary:
	if value == "":
		return {}
	var dot := value.find(".")
	if dot == -1:
		return { "map": value, "entry": "start" }
	return { "map": value.substr(0, dot), "entry": value.substr(dot + 1) }
