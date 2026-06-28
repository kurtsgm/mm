class_name OverworldMonsters
extends RefCounted

# 大地圖會走動的怪（MM3 風步進制）。純邏輯狀態機：玩家走一步 → step() 驅動範圍內的怪走一步。
# 不依賴 autoload：is_passable / is_defeated 皆由呼叫端注入；位置回寫存檔由 main.gd 負責。
const AGGRO_RANGE := 4   # Chebyshev：玩家進此範圍 → IDLE→CHASING
const LEASH_RANGE := 8   # Chebyshev：CHASING 離 home 超過此距離 → RETURNING（放棄）
enum State { IDLE, CHASING, RETURNING }

var _list: Array = []   # 每隻 { uid:String, group:String, home:Vector2i, cell:Vector2i, state:int }

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

# 從地圖 encounter 建立怪清單；已擊敗（is_defeated 注入）者跳過。每隻起始 home=cell=encounter 格、IDLE。
func init_from_map(map: MapData, is_defeated: Callable) -> void:
	_list.clear()
	for cell in map.encounters:
		var uid := map.get_encounter_uid(cell)
		if is_defeated.is_valid() and is_defeated.call(uid):
			continue
		_list.append({
			"uid": uid,
			"group": map.get_encounter(cell),
			"home": cell,
			"cell": cell,
			"state": State.IDLE,
		})

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
