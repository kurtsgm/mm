class_name MapLint
extends RefCounted

## Authored topology only. Encounters can be defeated; decorations do not block.
## Portal cells transition immediately; blocking NPCs must be approached from a neighbor.
static func load_maps() -> Dictionary:
	var maps := {}
	for id in ContentRegistry.ids("maps"):
		var map := MapImporter.parse(FileAccess.get_file_as_string(ContentRegistry.path_for("maps", id)))
		if map != null:
			map.map_id = id
			maps[id] = map
	return maps

static func walkable(map: MapData, pos: Vector2i) -> bool:
	if not MapBuilder.is_walkable_type(map.get_tile(pos)):
		return false
	return not bool(map.get_quest_giver(pos).get("blocks", false))

static func key(id: String, pos: Vector2i) -> String:
	return "%s:%d:%d" % [id, pos.x, pos.y]

static func edges(maps: Dictionary, id: String, pos: Vector2i) -> Array:
	var map: MapData = maps[id]
	var out := []
	if map.has_link(pos):
		var link := map.get_link(pos)
		var dest: MapData = maps.get(link["map"])
		if dest != null and dest.has_entry(link["entry"]):
			var p: Vector2i = dest.get_entry(link["entry"])["pos"]
			if walkable(dest, p):
				out.append({"map": dest.map_id, "pos": p})
		return out
	for dir in 4:
		var p := pos + GridDirection.to_vector(dir)
		var dest := map
		if p.x < 0 or p.y < 0 or p.x >= map.width or p.y >= map.height:
			dest = maps.get(map.get_neighbor(dir))
			if dest == null:
				continue
			p = Vector2i(posmod(p.x, dest.width), posmod(p.y, dest.height))
		if walkable(dest, p):
			out.append({"map": dest.map_id, "pos": p})
	return out

static func path(maps: Dictionary, source: Dictionary, target: Dictionary, adjacent := false) -> Array:
	if not maps.has(source["map"]) or not maps.has(target["map"]):
		return []
	if not walkable(maps[source["map"]], source["pos"]):
		return []
	var queue := [source]
	var previous := {key(source["map"], source["pos"]): -1}
	var index := 0
	while index < queue.size():
		var cell: Dictionary = queue[index]
		var distance: Vector2i = cell["pos"] - target["pos"]
		var arrived: bool = cell["map"] == target["map"] and (absi(distance.x) + absi(distance.y) == 1 if adjacent else distance == Vector2i.ZERO)
		if adjacent and (maps[cell["map"]] as MapData).has_link(cell["pos"]):
			arrived = false
		if arrived:
			var route := []
			while index != -1:
				cell = queue[index]
				route.push_front(cell)
				index = previous[key(cell["map"], cell["pos"])]
			return route
		for next in edges(maps, cell["map"], cell["pos"]):
			var k := key(next["map"], next["pos"])
			if not previous.has(k):
				previous[k] = index
				queue.append(next)
		index += 1
	return []

static func run(maps: Dictionary) -> Array:
	var errors := []
	for id in maps:
		var map: MapData = maps[id]
		if map.width != MapData.LOCAL_SIZE or map.height != MapData.LOCAL_SIZE:
			errors.append("map/%s: expected %dx%d" % [id, MapData.LOCAL_SIZE, MapData.LOCAL_SIZE])
		for dir in map.neighbors:
			var neighbor: MapData = maps.get(map.neighbors[dir])
			if neighbor == null or neighbor.get_neighbor((int(dir) + 2) % 4) != id:
				errors.append("map/%s: neighbor %s is missing or not reciprocal" % [id, map.neighbors[dir]])
			elif not _open_seam(map, neighbor, dir):
				errors.append("map/%s: no walkable seam to %s" % [id, neighbor.map_id])
		for name in map.entries:
			var p: Vector2i = map.entries[name]["pos"]
			if not walkable(map, p) or map.has_link(p):
				errors.append("map/%s: entry %s %s is blocked or on an automatic portal" % [id, name, p])
		var source := {"map": id, "pos": map.start_pos}
		var targets := []
		for p in map.links:
			targets.append({"pos": p, "kind": "portal"})
		for p in map.encounters:
			targets.append({"pos": p, "kind": "encounter"})
		for name in map.entries:
			targets.append({"pos": map.entries[name]["pos"], "kind": "entry/%s" % name})
		for entities in [map.objects, map.scenes, map.quest_givers, map.vendors, map.travels]:
			for entity in entities:
				targets.append({"pos": entity["pos"], "kind": "interaction", "adjacent": bool(entity.get("blocks", false))})
		for target in targets:
			if path(maps, source, {"map": id, "pos": target["pos"]}, target.get("adjacent", false)).is_empty():
				errors.append("map/%s: unreachable %s at %s from start" % [id, target["kind"], target["pos"]])
	return errors

static func _open_seam(map: MapData, neighbor: MapData, dir: int) -> bool:
	for i in map.width:
		var p: Vector2i
		var q: Vector2i
		match dir:
			GridDirection.Dir.NORTH:
				p = Vector2i(i, 0)
				q = Vector2i(i, neighbor.height - 1)
			GridDirection.Dir.SOUTH:
				p = Vector2i(i, map.height - 1)
				q = Vector2i(i, 0)
			GridDirection.Dir.EAST:
				p = Vector2i(map.width - 1, i)
				q = Vector2i(0, i)
			GridDirection.Dir.WEST:
				p = Vector2i(0, i)
				q = Vector2i(neighbor.width - 1, i)
		if walkable(map, p) and walkable(neighbor, q):
			return true
	return false
