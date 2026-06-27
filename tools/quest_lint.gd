class_name QuestLint
extends Object
# 任務內容靜態驗證器：交叉檢查 content/quests、content/dialogues、content/maps、content/monsters。
# run() -> { "errors": Array[String], "warnings": Array[String] }
# 供 /check-quest 的 CLI（tools/quest_lint_cli.gd）與迴歸測試（tests/content/test_quest_lint.gd）共用。
# 只依賴 class_name 全域（QuestCatalog/DialogueCatalog/MapImporter/ItemCatalog/MapData），不需 autoload。

const QUESTS_DIR := "res://content/quests"
const DIALOGUES_DIR := "res://content/dialogues"
const MAPS_DIR := "res://content/maps"
const MONSTERS_DIR := "res://content/monsters"

static func run() -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var quests := {}   # id -> QuestDef
	for qid in _json_ids(QUESTS_DIR):
		var d = QuestCatalog.load_quest(qid)
		if d == null:
			errors.append("[quest] %s.json 無法解析（stages/rewards 違規）" % qid)
		else:
			quests[qid] = d
	var monsters := _monster_ids()
	_check_stages(quests, monsters, errors)
	var refs := _scan_dialogues(quests, errors)   # { accept:{qid:true}, advance:{qid:true} }
	_check_completable(quests, refs, warnings)
	_check_maps(errors, warnings)
	return {"errors": errors, "warnings": warnings}

# --- internal ---

static func _json_ids(dir: String) -> Array:
	var out: Array = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".json"):
			out.append(f.get_basename())
	return out

static func _monster_ids() -> Dictionary:
	var out := {}
	var da := DirAccess.open(MONSTERS_DIR)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".tres"):
			var m = load(MONSTERS_DIR + "/" + f)
			if m != null and String(m.id) != "":
				out[String(m.id)] = true
	return out

static func _check_stages(quests: Dictionary, monsters: Dictionary, errors: Array) -> void:
	for qid in quests:
		var d = quests[qid]
		for i in d.stage_count():
			var st: Dictionary = d.stage(i)
			match String(st.get("type", "")):
				"kill":
					if not monsters.has(String(st.get("monster", ""))):
						errors.append("[quest] %s 階段%d kill 的 monster '%s' 在 content/monsters 找不到對應 id" % [qid, i, st.get("monster", "")])
				"collect":
					if not ItemCatalog.has_item(String(st.get("item", ""))):
						errors.append("[quest] %s 階段%d collect 的 item '%s' 不在 ItemCatalog" % [qid, i, st.get("item", "")])
				"reach":
					_check_reach(qid, i, st, errors)
		for it in d.rewards.get("items", []):
			if not ItemCatalog.has_item(String(it)):
				errors.append("[quest] %s reward item '%s' 不在 ItemCatalog" % [qid, it])

static func _check_reach(qid: String, i: int, st: Dictionary, errors: Array) -> void:
	var map_id := String(st.get("map", ""))
	var path := "%s/%s.json" % [MAPS_DIR, map_id]
	if not FileAccess.file_exists(path):
		errors.append("[quest] %s 階段%d reach 的 map '%s' 不存在" % [qid, i, map_id])
		return
	var map = MapImporter.parse(FileAccess.get_file_as_string(path))
	if map == null:
		errors.append("[quest] %s 階段%d reach 的 map '%s' 無法解析" % [qid, i, map_id])
		return
	var pos: Vector2i = st.get("pos", Vector2i(-1, -1))
	if pos.x < 0 or pos.x >= map.width or pos.y < 0 or pos.y >= map.height:
		errors.append("[quest] %s 階段%d reach 目標 %s 超出 %s 邊界" % [qid, i, pos, map_id])
	elif map.get_tile(pos) == MapData.TileType.WALL:
		errors.append("[quest] %s 階段%d reach 目標 %s 是牆、走不到" % [qid, i, pos, map_id])

static func _scan_dialogues(quests: Dictionary, errors: Array) -> Dictionary:
	var accept := {}
	var advance := {}
	for did in _json_ids(DIALOGUES_DIR):
		var raw = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [DIALOGUES_DIR, did]))
		if typeof(raw) != TYPE_DICTIONARY:
			errors.append("[dialogue] %s.json 不是合法 JSON 物件" % did)
			continue
		if DialogueCatalog.load_dialogue(did) == null:
			errors.append("[dialogue] %s.json 無法解析（DialogueData.parse 失敗：缺 start / goto 斷鏈）" % did)
		var nodes = raw.get("nodes", {})
		if typeof(nodes) != TYPE_DICTIONARY:
			continue
		for nid in nodes:
			for c in nodes[nid].get("choices", []):
				if typeof(c) != TYPE_DICTIONARY:
					continue
				_scan_require(did, c.get("require", null), quests, errors)
				for e in c.get("effects", []):
					if typeof(e) != TYPE_DICTIONARY:
						continue
					var op := String(e.get("op", ""))
					if op != "accept_quest" and op != "advance_quest":
						continue
					var qid := String(e.get("quest", ""))
					if not quests.has(qid):
						errors.append("[dialogue] %s 的 %s 指向不存在的任務 '%s'" % [did, op, qid])
					elif op == "accept_quest":
						accept[qid] = true
					else:
						advance[qid] = true
	return {"accept": accept, "advance": advance}

static func _scan_require(did: String, require, quests: Dictionary, errors: Array) -> void:
	if typeof(require) != TYPE_DICTIONARY:
		return
	for key in require:
		var qid := ""
		match key:
			"quest_active", "quest_done", "quest_inactive":
				qid = String(require[key])
			"quest_stage":
				if typeof(require[key]) == TYPE_DICTIONARY:
					qid = String(require[key].get("id", ""))
		if qid != "" and not quests.has(qid):
			errors.append("[dialogue] %s 的 require '%s' 指向不存在的任務 '%s'" % [did, key, qid])

static func _check_completable(quests: Dictionary, refs: Dictionary, warnings: Array) -> void:
	for qid in quests:
		if not refs["accept"].has(qid):
			warnings.append("[quest] %s 沒有任何對話會 accept_quest → 玩家無法接取" % qid)
		var d = quests[qid]
		var has_talk := false
		for i in d.stage_count():
			if String(d.stage(i).get("type", "")) == "talk":
				has_talk = true
		if has_talk and not refs["advance"].has(qid):
			warnings.append("[quest] %s 有 talk 階段但沒有任何對話會 advance_quest → 無法回報完成" % qid)

static func _check_maps(errors: Array, warnings: Array) -> void:
	for mid in _json_ids(MAPS_DIR):
		var map = MapImporter.parse(FileAccess.get_file_as_string("%s/%s.json" % [MAPS_DIR, mid]))
		if map == null:
			errors.append("[map] %s.json 無法解析" % mid)
			continue
		for q in map.quest_givers:
			if DialogueCatalog.load_dialogue(String(q.get("dialogue", ""))) == null:
				errors.append("[map] %s questgiver@%s 的對話 '%s' 不存在/無法解析" % [mid, q.get("pos"), q.get("dialogue", "")])
		_check_cell_collisions(mid, map, warnings)

static func _check_cell_collisions(mid: String, map, warnings: Array) -> void:
	var seen := {}   # Vector2i -> Array[String type]
	for e in map.quest_givers:
		_mark(seen, e.get("pos"), "questgiver")
	for e in map.vendors:
		_mark(seen, e.get("pos"), "vendor")
	for e in map.scenes:
		_mark(seen, e.get("pos"), "scene")
	for o in map.objects:
		_mark(seen, o.get("pos"), "chest")
	for pos in map.encounters:
		_mark(seen, pos, "monster")
	for pos in map.links:
		_mark(seen, pos, "portal")
	for pos in seen:
		var types: Array = seen[pos]
		if types.size() <= 1:
			continue
		# chest+monster 同格＝刻意允許（看守寶箱：先戰鬥後開箱），不警告
		if types.size() == 2 and types.has("chest") and types.has("monster"):
			continue
		warnings.append("[map] %s 格 %s 同時有互動物件：%s（dispatch 只會觸發其一）" % [mid, pos, ", ".join(types)])

static func _mark(seen: Dictionary, pos, t: String) -> void:
	if pos == null:
		return
	if not seen.has(pos):
		seen[pos] = []
	seen[pos].append(t)
