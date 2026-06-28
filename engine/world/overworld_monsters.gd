class_name OverworldMonsters
extends RefCounted

# 大地圖會走動的怪（MM3 風步進制）。純邏輯狀態機：玩家走一步 → step() 驅動範圍內的怪走一步。
# 不依賴 autoload：is_passable / is_defeated 皆由呼叫端注入；位置回寫存檔由 main.gd 負責。
const AGGRO_RANGE := 4   # Chebyshev：玩家進此範圍 → IDLE→CHASING
const LEASH_RANGE := 8   # Chebyshev：CHASING 離 home 超過此距離 → RETURNING（放棄）
enum State { IDLE, CHASING, RETURNING }

var _list: Array = []   # 每隻 { uid:String, group:String, origin_map:String, origin_off:Vector2i, home:Vector2i, cell:Vector2i, state:int }（home/cell 為全域格）

# Chebyshev 距離（八方等距）：max(|dx|, |dy|)。
static func cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

# 4 向 BFS 求 from→goal 最短路的「第一步」。occupied（Dictionary 或 Array of Vector2i）視為不可踏，
# 但 goal 一律可當終點（怪能踏上玩家格＝接觸）。無路或被堵 → 回 from（不動）。
static func next_step(from: Vector2i, goal: Vector2i, is_passable: Callable, occupied) -> Vector2i:
	if from == goal:
		return from
	var blocked := _as_set(occupied)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var came := {from: from}   # 每格記其來源格，用以回溯第一步
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			var node := cur
			while came[node] != from:
				node = came[node]
			return node
		for d in dirs:
			var nxt: Vector2i = cur + d
			if came.has(nxt):
				continue
			var walkable: bool = (nxt == goal) or (is_passable.call(nxt) and not blocked.has(nxt))
			if not walkable:
				continue
			came[nxt] = cur
			queue.append(nxt)
	return from

# occupied 統一成 set（Dictionary[Vector2i→true]）。
static func _as_set(occupied) -> Dictionary:
	if occupied is Dictionary:
		return occupied
	var out: Dictionary = {}
	if occupied is Array:
		for c in occupied:
			out[c] = true
	return out

# 從地圖 encounter 建怪清單（單圖特例：放在全域原點）。
func init_from_map(map: MapData, is_defeated: Callable) -> void:
	_list.clear()
	_add_map(map, Vector2i.ZERO, is_defeated, {})

# 把一張圖的 encounters 投影成全域 entry 加入 _list。
# offset=該圖在當前框架的全域偏移；saved（該圖 { uid:{cell:原生相對 local, state} }）相符 uid 覆寫 cell(+offset)/state。
func _add_map(map: MapData, offset: Vector2i, is_defeated: Callable, saved: Dictionary) -> void:
	for cell in map.encounters:
		var uid := map.get_encounter_uid(cell)
		if is_defeated.is_valid() and is_defeated.call(uid):
			continue
		var home_global: Vector2i = cell + offset
		var cur := home_global
		var st := State.IDLE
		if saved.has(uid):
			var rec: Dictionary = saved[uid]
			cur = Vector2i(rec["cell"]) + offset
			st = int(rec["state"])
		_list.append({
			"uid": uid,
			"group": map.get_encounter(cell),
			"origin_map": map.map_id,
			"origin_off": offset,
			"home": home_global,
			"cell": cur,
			"state": st,
		})

# 從 WorldGrid.regions()（[{map, ox, oy}]）建統一全域怪集（含當前圖 + 鄰圖）。
# is_defeated 注入；saved_provider(map_id) 回該圖 { uid:{cell:原生相對 local, state} }（非 Dictionary 當空）。
func init_from_regions(regions: Array, is_defeated: Callable, saved_provider: Callable) -> void:
	_list.clear()
	for region in regions:
		var map: MapData = region["map"]
		if map == null:
			continue
		var offset := Vector2i(int(region["ox"]), int(region["oy"]))
		var saved = saved_provider.call(map.map_id)
		if typeof(saved) != TYPE_DICTIONARY:
			saved = {}
		_add_map(map, offset, is_defeated, saved)

# 給呈現層用的快照（不含 home/內部欄位）。
func live() -> Array:
	var out: Array = []
	for m in _list:
		out.append({"uid": m["uid"], "group": m["group"], "cell": m["cell"], "state": m["state"]})
	return out

func home_of(uid: String) -> Vector2i:
	for m in _list:
		if m["uid"] == uid:
			return m["home"]
	return Vector2i(-1, -1)

func remove(uid: String) -> void:
	for i in range(_list.size() - 1, -1, -1):
		if _list[i]["uid"] == uid:
			_list.remove_at(i)

# 玩家走一步 → 驅動範圍內的怪走一步（步進制）。回 { contact: uid_or_"", moved: [uid...] }。
# is_passable: func(cell:Vector2i)->bool（= in_bounds and is_walkable；占用由本函式內部處理）。
func step(player_cell: Vector2i, is_passable: Callable) -> Dictionary:
	# 1. 先判即時接觸：玩家剛走進站著的怪 → 不移動任何怪。
	for m in _list:
		if m["cell"] == player_cell:
			return {"contact": m["uid"], "moved": []}
	# 2. 逐隻跑狀態機並移動一步（依 _list 順序，確定性）。
	var occupied := _occupied_set()
	var moved: Array = []
	for m in _list:
		var before: Vector2i = m["cell"]
		_step_one(m, player_cell, is_passable, occupied)
		var after: Vector2i = m["cell"]
		if after != before:
			occupied.erase(before)   # 移走舊格、加入新格，避免後續怪疊上來
			occupied[after] = true
			moved.append(m["uid"])
	# 3. 移動後再判接觸：怪走進玩家。
	var contact := ""
	for m in _list:
		if m["cell"] == player_cell:
			contact = m["uid"]
			break
	return {"contact": contact, "moved": moved}

# 單隻狀態機一步（就地改 m["cell"]/m["state"]）。
func _step_one(m: Dictionary, player_cell: Vector2i, is_passable: Callable, occupied: Dictionary) -> void:
	match m["state"]:
		State.IDLE:
			if cheb(m["cell"], player_cell) <= AGGRO_RANGE:
				m["state"] = State.CHASING
				_chase(m, player_cell, is_passable, occupied)
		State.CHASING:
			_chase(m, player_cell, is_passable, occupied)
		State.RETURNING:
			m["cell"] = next_step(m["cell"], m["home"], is_passable, occupied)
			if m["cell"] == m["home"]:
				m["state"] = State.IDLE

func _chase(m: Dictionary, player_cell: Vector2i, is_passable: Callable, occupied: Dictionary) -> void:
	if cheb(m["cell"], m["home"]) > LEASH_RANGE:
		m["state"] = State.RETURNING
		m["cell"] = next_step(m["cell"], m["home"], is_passable, occupied)
		if m["cell"] == m["home"]:
			m["state"] = State.IDLE
		return
	m["cell"] = next_step(m["cell"], player_cell, is_passable, occupied)

func _occupied_set() -> Dictionary:
	var out: Dictionary = {}
	for m in _list:
		out[m["cell"]] = true
	return out

# 回 { origin_map: { uid: {"cell": Vector2i(原生相對 local), "state": int} } }。
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for m in _list:
		var mid: String = m["origin_map"]
		if not out.has(mid):
			out[mid] = {}
		out[mid][m["uid"]] = {"cell": m["cell"] - m["origin_off"], "state": m["state"]}
	return out

# 戰鬥身分：回 { group, origin_map, home_local }（home_local = 全域 home - origin_off = 原生圖上的 home 格）。
func combat_info(uid: String) -> Dictionary:
	for m in _list:
		if m["uid"] == uid:
			return {"group": m["group"], "origin_map": m["origin_map"], "home_local": m["home"] - m["origin_off"]}
	return {}
