class_name RegionFlow
extends RefCounted

## Content integration replay, using real dialogue/effect/quest/save implementations.
## Routes assume encounters are beatable. Combat, input and presentation need playtest.
var maps: Dictionary
var state
var errors: Array = []
var trace: Array = []
var walked_cells := 0
var _initial_gold := 0

func _init(all_maps: Dictionary, gs) -> void:
	maps = all_maps
	state = gs
	_initial_gold = gs.gold

func begin(start: Dictionary) -> bool:
	var map: MapData = maps.get(start.get("map", ""))
	if map == null or not map.has_entry(start.get("entry", "start")):
		return fail("missing start map/entry: %s" % start)
	state.current_map_id = map.map_id
	state.player_pos = map.get_entry(start.get("entry", "start"))["pos"]
	state.player_facing = map.get_entry(start.get("entry", "start"))["facing"]
	state.mark_explored(map.map_id, state.player_pos, map.width, map.height)
	return true

func fail(message: String) -> bool:
	errors.append(message)
	return false

func step(spec: Dictionary) -> bool:
	trace.append(spec.duplicate(true))
	var op := String(spec.get("op", ""))
	if op == "expect":
		if not DialogueCondition.passes(spec.get("require"), state):
			return fail("condition failed: %s" % spec.get("require"))
		if spec.has("gold_delta") and state.gold - _initial_gold != int(spec["gold_delta"]):
			return fail("gold delta: expected %s, got %d" % [spec["gold_delta"], state.gold - _initial_gold])
		for id in spec.get("items", {}):
			if state.inventory.count_of(id) != int(spec["items"][id]):
				return fail("item count mismatch: %s" % id)
		return true
	if op == "reload":
		var saver = load("res://autoload/save_system.gd").new()
		var manager = load("res://autoload/map_manager.gd").new()
		var raw: Variant = JSON.parse_string(JSON.stringify(SaveSerializer.to_dict(saver.capture_from(state))))
		var restored := SaveSerializer.from_dict(raw)
		if restored == null:
			saver.free()
			manager.free()
			return fail("save serialization failed")
		saver.apply_to(restored, state, manager)
		saver.free()
		manager.free()
		return true
	if not ["visit", "talk", "scene", "chest"].has(op):
		return fail("unsupported operation: %s" % op)
	var id := String(spec.get("map", ""))
	var p := Vector2i(int(spec["pos"][0]), int(spec["pos"][1]))
	var map: MapData = maps.get(id)
	if map == null:
		return fail("missing map: %s" % id)
	var adjacent := op == "talk" and bool(map.get_quest_giver(p).get("blocks", false))
	if not move_to(id, p, adjacent):
		return false
	match op:
		"visit":
			var scene := map.get_scene(p)
			if not scene.is_empty() and SceneTrigger.should_trigger(scene, state, state.is_scene_triggered(id, p)):
				return fail("visit ends on active scene; use a scene step")
			return true
		"talk":
			var npc := map.get_quest_giver(p)
			if npc.is_empty():
				return fail("%s %s: no NPC" % [id, p])
			return dialogue(DialogueCatalog.load_dialogue(npc["dialogue"]), spec.get("choices", []))
		"chest":
			var chest := map.get_object(p)
			if chest.is_empty():
				return fail("%s %s: no chest" % [id, p])
			if not state.is_object_opened(id, p):
				state.mark_object_opened(id, p)
				state.gold += int(chest["gold"])
				for item in chest["items"]:
					state.inventory.add(item, 1)
				state.refresh_collect()
			return true
		"scene":
			var scene := map.get_scene(p)
			if scene.is_empty():
				return fail("%s %s: no scene" % [id, p])
			var run: NarrativeScene = state.narrative().begin_scene(id, p, scene)
			if spec.get("blocked", false):
				return true if run == null else fail("scene unexpectedly available: %s %s" % [id, p])
			if run == null:
				return fail("scene not available: %s %s" % [id, p])
			if spec.get("abort", false):
				run.complete(false)
				return true
			var ok := true
			var scripts: Array = spec.get("dialogues", [])
			if run.dialogue != null:
				ok = dialogue(run.dialogue, spec.get("choices", []))
			else:
				var index := 0
				for part in run.cutscene.steps:
					if part["type"] == "dialogue":
						if index >= scripts.size():
							ok = fail("missing cutscene dialogue choices")
						else:
							ok = dialogue(DialogueCatalog.load_dialogue(part["dialogue"]), scripts[index])
						index += 1
					elif part["type"] == "effects":
						ok = StoryEffects.apply(part["effects"], state).ok
						if not ok:
							fail("cutscene story effects failed")
					if not ok:
						break
				if ok and index != scripts.size():
					ok = fail("unused cutscene dialogue choices")
			run.complete(ok)
			return ok
	return false

func move_to(id: String, pos: Vector2i, adjacent := false) -> bool:
	if (maps[id] as MapData).has_link(pos):
		return fail("automatic portal is not a stopping point; target its destination entry")
	var route := MapLint.path(maps, {"map": state.current_map_id, "pos": state.player_pos}, {"map": id, "pos": pos}, adjacent)
	if route.is_empty():
		return fail("no route from %s %s to %s %s" % [state.current_map_id, state.player_pos, id, pos])
	for index in range(1, route.size()):
		var cell: Dictionary = route[index]
		var map: MapData = maps[cell["map"]]
		var scene := map.get_scene(cell["pos"])
		if index < route.size() - 1 and not scene.is_empty() and SceneTrigger.should_trigger(scene, state, state.is_scene_triggered(cell["map"], cell["pos"])):
			return fail("route crosses unhandled scene: %s %s; add a scene step" % [cell["map"], cell["pos"]])
		state.current_map_id = cell["map"]
		state.player_pos = cell["pos"]
		state.mark_explored(cell["map"], cell["pos"], map.width, map.height)
		state.notify_enter(cell["map"], cell["pos"])
		walked_cells += 1
	return true

func dialogue(data: DialogueData, selections: Array) -> bool:
	if data == null:
		return fail("missing dialogue")
	var runner := DialogueRunner.new(data, state)
	for selection in selections:
		var matches := []
		for choice in runner.available_choices():
			if choice["goto"] == selection:
				matches.append(choice)
		if matches.size() != 1:
			return fail("dialogue/%s: expected one available choice to %s, got %d" % [data.id, str(selection), matches.size()])
		var result := runner.choose(matches[0])
		if not result.ok:
			return fail("dialogue/%s: choice failed (%s)" % [data.id, result.reason])
	if not runner.is_finished():
		return fail("dialogue/%s: replay ended before dialogue completion" % data.id)
	return true
