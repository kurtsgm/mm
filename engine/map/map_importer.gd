class_name MapImporter
extends Object

# JSON 地圖 → MapData；任何違規 → null（不做 log 副作用）。
# grid 為 ASCII 列字串陣列（字元集 # . @ D < >）；怪物/portal 走 entities，不再用格子字元。
static func parse(json_text: String) -> MapData:
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return null
	var root = json.data
	if typeof(root) != TYPE_DICTIONARY:
		return null
	if not root.has("grid"):
		return null

	var grid := _parse_grid(root["grid"])
	if grid.is_empty():
		return null

	var entities = _parse_entities(root.get("entities", []), grid["width"], grid["height"])
	if entities == null:
		return null

	var map := MapData.new()
	map.width = grid["width"]
	map.height = grid["height"]
	map.tiles = grid["tiles"]
	map.start_pos = grid["start_pos"]
	map.start_facing = GridDirection.Dir.NORTH

	var theme := String(root.get("theme", ""))
	map.theme_id = theme if theme != "" else "default"
	map.display_name = String(root.get("name", ""))
	map.neighbors = _parse_neighbors(root.get("neighbors", {}))

	var entries := _parse_entries(root.get("entries", {}))
	entries["start"] = {"pos": map.start_pos, "facing": GridDirection.Dir.NORTH}
	map.entries = entries

	map.encounters = entities["encounters"]
	map.links = entities["links"]
	map.decorations = entities["decorations"]
	return map

# --- internal ---

# rows -> { width, height, tiles, start_pos }；任何違規 → {}（空 = 失敗）。
static func _parse_grid(rows) -> Dictionary:
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		return {}
	if typeof(rows[0]) != TYPE_STRING:
		return {}
	var height: int = rows.size()
	var width: int = (rows[0] as String).length()
	if width == 0:
		return {}
	var tiles := PackedInt32Array()
	tiles.resize(width * height)
	var start_pos := Vector2i(-1, -1)
	for y in height:
		if typeof(rows[y]) != TYPE_STRING:
			return {}
		var line: String = rows[y]
		if line.length() != width:
			return {}
		for x in width:
			var t := _char_to_tile(line[x])
			if t == -1:
				return {}
			if line[x] == "@":
				if start_pos != Vector2i(-1, -1):
					return {}
				start_pos = Vector2i(x, y)
			tiles[y * width + x] = t
	if start_pos == Vector2i(-1, -1):
		return {}
	return {"width": width, "height": height, "tiles": tiles, "start_pos": start_pos}

# arr -> { encounters, links, decorations }；違規 → null。空陣列為合法（回空集合）。
static func _parse_entities(arr, width: int, height: int):
	if typeof(arr) != TYPE_ARRAY:
		return null
	var encounters := {}
	var links := {}
	var decorations := []
	for e in arr:
		if typeof(e) != TYPE_DICTIONARY:
			return null
		if not (e.has("type") and e.has("pos")):
			return null
		var pos = _parse_pos(e["pos"])
		if pos == null:
			return null
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			return null
		match String(e["type"]):
			"monster":
				if not e.has("encounter"):
					return null
				encounters[pos] = String(e["encounter"])
			"portal":
				if not e.has("to"):
					return null
				links[pos] = {"map": String(e["to"]), "entry": String(e.get("entry", "start"))}
			"decoration":
				if not e.has("model"):
					return null
				var facing := GridDirection.Dir.NORTH
				if e.has("facing"):
					facing = _facing_word_to_dir(String(e["facing"]))
				var scale := 1.0
				if e.has("scale"):
					if not _is_num(e["scale"]):
						return null
					scale = float(e["scale"])
				decorations.append({"pos": pos, "model": String(e["model"]), "facing": facing, "scale": scale})
			_:
				return null
	return {"encounters": encounters, "links": links, "decorations": decorations}

# [x, y] -> Vector2i；違規 → null。JSON 數字可能是 float，需 int() 轉。
static func _parse_pos(v):
	if typeof(v) != TYPE_ARRAY or v.size() < 2:
		return null
	if not (_is_num(v[0]) and _is_num(v[1])):
		return null
	return Vector2i(int(v[0]), int(v[1]))

static func _is_num(x) -> bool:
	return typeof(x) == TYPE_INT or typeof(x) == TYPE_FLOAT

static func _parse_neighbors(d) -> Dictionary:
	var out := {}
	if typeof(d) != TYPE_DICTIONARY:
		return out
	for key in ["north", "east", "south", "west"]:
		var v = d.get(key, "")
		if typeof(v) == TYPE_STRING and v != "":
			out[_word_to_dir(key)] = v
	return out

# { name: { pos:[x,y], facing?:"N/E/S/W" } } -> entries dict；畸形項目跳過（沿用既有 entry 容忍）。
static func _parse_entries(d) -> Dictionary:
	var out := {}
	if typeof(d) != TYPE_DICTIONARY:
		return out
	for name in d:
		var spec = d[name]
		if typeof(spec) != TYPE_DICTIONARY or not spec.has("pos"):
			continue
		var pos = _parse_pos(spec["pos"])
		if pos == null:
			continue
		var facing := GridDirection.Dir.NORTH
		if spec.has("facing"):
			facing = _facing_word_to_dir(String(spec["facing"]))
		out[String(name)] = {"pos": pos, "facing": facing}
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
