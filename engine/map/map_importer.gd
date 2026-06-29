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
	# 建築 footprint 蓋牆/門地板：事後覆寫 tiles（grid 為基底，建築自蓋）。
	for cell in entities["tile_overrides"]:
		map.tiles[cell.y * map.width + cell.x] = entities["tile_overrides"][cell]
	map.start_pos = grid["start_pos"]
	map.start_facing = GridDirection.Dir.NORTH

	var theme := String(root.get("theme", ""))
	map.theme_id = theme if theme != "" else "default"
	map.display_name = String(root.get("name", ""))
	map.neighbors = _parse_neighbors(root.get("neighbors", {}))

	var entries := _parse_entries(root.get("entries", {}))
	entries["start"] = {"pos": map.start_pos, "facing": GridDirection.Dir.NORTH}
	for ename in entities["extra_entries"]:   # 建築衍生的 <id>_out 回程入口
		entries[ename] = entities["extra_entries"][ename]
	map.entries = entries

	map.encounters = entities["encounters"]
	map.encounter_uids = entities["encounter_uids"]
	map.links = entities["links"]
	map.decorations = entities["decorations"]
	map.objects = entities["objects"]
	map.scenes = entities["scenes"]
	map.vendors = entities["vendors"]
	map.quest_givers = entities["quest_givers"]
	map.buildings = entities["buildings"]
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

# arr -> { encounters, links, decorations, objects, scenes, vendors }；違規 → null。空陣列為合法（回空集合）。
static func _parse_entities(arr, width: int, height: int):
	if typeof(arr) != TYPE_ARRAY:
		return null
	var encounters := {}
	var encounter_uids := {}
	var links := {}
	var decorations := []
	var objects := []
	var scenes := []
	var vendors := []
	var quest_givers := []
	var buildings := []
	var tile_overrides := {}   # Vector2i -> TileType（建築蓋牆/門地板，事後套用到 tiles）
	var extra_entries := {}    # name -> { pos, facing }（建築衍生的 <id>_out 回程入口）
	for e in arr:
		if typeof(e) != TYPE_DICTIONARY:
			return null
		if not e.has("type"):
			return null
		if String(e["type"]) == "building":
			if not _apply_building(e, width, height, tile_overrides, links, decorations, buildings, extra_entries):
				return null
			continue
		if not e.has("pos"):
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
				encounter_uids[pos] = String(e.get("id", ""))
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
			"chest":
				var items: Array = []
				if e.has("items"):
					if typeof(e["items"]) != TYPE_ARRAY:
						return null
					for it in e["items"]:
						items.append(String(it))
				var gold := 0
				if e.has("gold"):
					if not _is_num(e["gold"]) or int(e["gold"]) < 0:
						return null
					gold = int(e["gold"])
				var model := "chest"
				if e.has("model"):
					model = String(e["model"])
				objects.append({"pos": pos, "items": items, "gold": gold, "model": model})
			"scene":
				if not e.has("dialogue"):
					return null
				var once := false
				if e.has("once"):
					once = bool(e["once"])
				scenes.append({
					"pos": pos,
					"dialogue": String(e["dialogue"]),
					"require": e.get("require", null),
					"once": once,
				})
			"vendor":
				if not e.has("id"):
					return null
				vendors.append({"pos": pos, "id": String(e["id"])})
			"questgiver":
				if not e.has("dialogue"):
					return null
				quest_givers.append({"pos": pos, "dialogue": String(e["dialogue"])})
			_:
				return null
	return {"encounters": encounters, "encounter_uids": encounter_uids, "links": links, "decorations": decorations, "objects": objects, "scenes": scenes, "vendors": vendors, "quest_givers": quest_givers, "buildings": buildings, "tile_overrides": tile_overrides, "extra_entries": extra_entries}

# `building` entity 展開：蓋牆/門地板（tile_overrides）、門→室內 link、衍生 <id>_out 入口、
# 選擇性 model 裝飾、記錄到 buildings。違規 → false（呼叫端回 null）。
static func _apply_building(e, width: int, height: int, overrides: Dictionary, links: Dictionary, decorations: Array, buildings: Array, extra_entries: Dictionary) -> bool:
	if not e.has("id") or typeof(e["id"]) != TYPE_STRING or String(e["id"]) == "":
		return false
	var id: String = String(e["id"])
	if not e.has("rect"):
		return false
	var rect = _parse_rect(e["rect"], width, height)
	if rect == null:
		return false
	var rx: int = rect[0]
	var ry: int = rect[1]
	var rw: int = rect[2]
	var rh: int = rect[3]
	var facing := GridDirection.Dir.NORTH
	if e.has("facing"):
		facing = _facing_word_to_dir(String(e["facing"]))
	var model := ""
	if e.has("model"):
		model = String(e["model"])
	var scale := 1.0
	if e.has("scale"):
		if not _is_num(e["scale"]):
			return false
		scale = float(e["scale"])
	# 門（選擇性）：有門才連室內、才產生回程入口
	var door = null
	if e.has("door"):
		door = _parse_pos(e["door"])
		if door == null:
			return false
		if door.x < rx or door.x >= rx + rw or door.y < ry or door.y >= ry + rh:
			return false
		if not e.has("interior") or String(e.get("interior", "")) == "":
			return false
	# 蓋牆
	for yy in range(ry, ry + rh):
		for xx in range(rx, rx + rw):
			overrides[Vector2i(xx, yy)] = MapData.TileType.WALL
	var interior := ""
	if door != null:
		interior = String(e["interior"])
		overrides[door] = MapData.TileType.FLOOR
		var entry := "from_town"
		if e.has("entry"):
			entry = String(e["entry"])
		links[door] = {"map": interior, "entry": entry}
		var front: Vector2i = door + GridDirection.to_vector(facing)
		if front.x < 0 or front.x >= width or front.y < 0 or front.y >= height:
			return false
		extra_entries[id + "_out"] = {"pos": front, "facing": facing}
	if model != "":
		decorations.append({"pos": Vector2i(rx, ry), "model": model, "facing": GridDirection.Dir.NORTH, "scale": scale})
	buildings.append({
		"id": id,
		"rect": [rx, ry, rw, rh],
		"door": door if door != null else Vector2i(-1, -1),
		"facing": facing,
		"interior": interior,
		"model": model,
	})
	return true

# [x, y, w, h] -> [rx, ry, rw, rh]；違規（非 4 數、w/h<1、出界）→ null。
static func _parse_rect(v, width: int, height: int):
	if typeof(v) != TYPE_ARRAY or v.size() < 4:
		return null
	for n in v:
		if not _is_num(n):
			return null
	var rx := int(v[0])
	var ry := int(v[1])
	var rw := int(v[2])
	var rh := int(v[3])
	if rw < 1 or rh < 1:
		return null
	if rx < 0 or ry < 0 or rx + rw > width or ry + rh > height:
		return null
	return [rx, ry, rw, rh]

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
