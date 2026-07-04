class_name LootRoller
extends Object

# 程序掉落核心（純函式，RNG 注入）。bases 由呼叫端（presentation/LootPool）注入。
enum Source { OVERWORLD, DUNGEON }

# tier(1..10) × 品質權重 [common, fine, rare, legendary]。source=DUNGEON 額外上移。
const _QW := [
	[85, 14, 1, 0],    # T1
	[78, 19, 3, 0],    # T2
	[70, 24, 6, 0],    # T3
	[62, 29, 8, 1],    # T4
	[54, 33, 11, 2],   # T5
	[46, 37, 15, 2],   # T6
	[38, 40, 19, 3],   # T7
	[30, 42, 24, 4],   # T8
	[22, 43, 30, 5],   # T9
	[15, 42, 36, 7],   # T10
]
const MAX_PREFIX := 3
const MAX_SUFFIX := 3

static func tier_for(level: int) -> int:
	return clampi(int(ceil(level / 10.0)), 1, 10)

static func roll_quality(tier: int, source: int, rng: RandomNumberGenerator) -> int:
	var w: Array = (_QW[tier - 1]).duplicate()
	if source == Source.DUNGEON:
		# 地城：把權重往高品質搬（common→fine、fine→rare、rare→legendary 各挪一部分）
		var shift_c: int = w[0] / 3
		var shift_f: int = w[1] / 4
		var shift_r: int = w[2] / 4
		w[0] -= shift_c; w[1] += shift_c - shift_f
		w[2] += shift_f - shift_r; w[3] += shift_r
	var total := 0
	for x in w: total += int(x)
	var pick := rng.randi_range(1, maxi(1, total))
	var acc := 0
	for q in w.size():
		acc += int(w[q])
		if pick <= acc:
			return q
	return Quality.Q.COMMON

static func _pick_base(bases: Array, level: int, rng: RandomNumberGenerator) -> ItemDef:
	var pool: Array = []
	var total := 0
	for d in bases:
		if d.drop_weight > 0 and d.min_level <= level and level <= d.max_level:
			pool.append(d); total += d.drop_weight
	if pool.is_empty():
		return null
	var pick := rng.randi_range(1, total)
	var acc := 0
	for d in pool:
		acc += d.drop_weight
		if pick <= acc:
			return d
	return pool[0]

static func roll(bases: Array, monster_level: int, source: int, rng: RandomNumberGenerator) -> ItemInstance:
	var def := _pick_base(bases, monster_level, rng)
	if def == null:
		return null
	var ilvl := clampi(monster_level, 1, 100)
	var tier := tier_for(monster_level)
	var quality := roll_quality(tier, source, rng)
	var it := ItemInstance.new()
	it.base_id = def.id
	it.ilvl = ilvl
	it.quality = quality
	if quality == Quality.Q.LEGENDARY:
		var uids: Array = UniqueCatalog.eligible(ilvl)
		if not uids.is_empty():
			it.unique_id = uids[rng.randi_range(0, uids.size() - 1)]
			return it
		quality = Quality.Q.RARE   # 無合格 unique → 降級為稀有
		it.quality = quality
	it.affixes = _roll_affixes(def.category, ilvl, Quality.affix_count(quality, rng), rng)
	return it

static func _roll_affixes(category: int, ilvl: int, count: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var used: Dictionary = {}
	var n_pre := 0
	var n_suf := 0
	var attempts := 0
	while out.size() < count and attempts < count * 8:
		attempts += 1
		var kind := AffixCatalog.PREFIX if rng.randi_range(0, 1) == 0 else AffixCatalog.SUFFIX
		if kind == AffixCatalog.PREFIX and n_pre >= MAX_PREFIX:
			kind = AffixCatalog.SUFFIX
		if kind == AffixCatalog.SUFFIX and n_suf >= MAX_SUFFIX:
			kind = AffixCatalog.PREFIX
		var ids: Array = AffixCatalog.eligible(category, ilvl, kind)
		# 過濾已用
		var fresh: Array = []
		for id in ids:
			if not used.has(id): fresh.append(id)
		if fresh.is_empty():
			continue
		var chosen: String = fresh[rng.randi_range(0, fresh.size() - 1)]
		used[chosen] = true
		var e: Dictionary = AffixCatalog.entry(chosen)
		var entry: Dictionary = {"id": chosen, "kind": kind, "mods": AffixCatalog.roll_mods(chosen, rng)}
		if not (e.get("on_hit", {}) as Dictionary).is_empty():
			entry["on_hit"] = e["on_hit"]
		if not (e.get("resist", {}) as Dictionary).is_empty():
			entry["resist"] = e["resist"]
		out.append(entry)
		if kind == AffixCatalog.PREFIX: n_pre += 1
		else: n_suf += 1
	return out
