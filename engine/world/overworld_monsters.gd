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
