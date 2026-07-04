class_name Quality
extends Object

# 品質階常數表（4 階）。仿 MonsterTiers 風格；數值由模擬器調校。
enum Q { COMMON, FINE, RARE, LEGENDARY }

# idx → {id, name, color(hex), affix_min, affix_max, value_mult}
const _Q := [
	{"id": "common",    "name": "普通", "color": "#c8c8c8", "amin": 0, "amax": 0, "mult": 1.0},
	{"id": "fine",      "name": "精良", "color": "#4caf50", "amin": 1, "amax": 1, "mult": 1.5},
	{"id": "rare",      "name": "稀有", "color": "#9c27b0", "amin": 2, "amax": 3, "mult": 3.5},
	{"id": "legendary", "name": "傳說", "color": "#ff9800", "amin": 4, "amax": 5, "mult": 10.0},
]

static func affix_count(q: int, rng: RandomNumberGenerator) -> int:
	var e: Dictionary = _Q[q]
	return rng.randi_range(int(e["amin"]), int(e["amax"]))

static func color(q: int) -> Color:
	return Color(String(_Q[q]["color"]))

static func value_mult(q: int) -> float:
	return float(_Q[q]["mult"])

static func display_name(q: int) -> String:
	return String(_Q[q]["name"])

static func id(q: int) -> String:
	return String(_Q[q]["id"])

static func from_id(s: String) -> int:
	for i in _Q.size():
		if _Q[i]["id"] == s:
			return i
	return Q.COMMON
