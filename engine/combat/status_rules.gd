class_name StatusRules
extends Object

# 對一串 StatusEffect 做純行為解讀。雙方（Character/Monster）與戰鬥/地表流程共用。
const PARALYSIS_SKIP_CHANCE := 0.5

static func stat_total(statuses: Array, stat: int) -> int:
	var total := 0
	for s in statuses:
		if s.kind == StatusEffect.Kind.STAT_MOD and s.stat == stat:
			total += s.amount
	return total

# POISON + BURN 的 potency 加總（單跳總傷害）
static func turn_damage(statuses: Array) -> int:
	var total := 0
	for s in statuses:
		if s.kind == StatusEffect.Kind.POISON or s.kind == StatusEffect.Kind.BURN:
			total += s.potency
	return total

static func incapacitating(statuses: Array) -> bool:
	for s in statuses:
		if s.kind == StatusEffect.Kind.SLEEP or s.kind == StatusEffect.Kind.PARALYSIS:
			return true
	return false

# SLEEP → 一律阻止；PARALYSIS → roll < PARALYSIS_SKIP_CHANCE 才阻止。roll 由呼叫端傳（保純函式）。
static func prevents_action(statuses: Array, roll: float) -> bool:
	for s in statuses:
		if s.kind == StatusEffect.Kind.SLEEP:
			return true
	for s in statuses:
		if s.kind == StatusEffect.Kind.PARALYSIS:
			return roll < PARALYSIS_SKIP_CHANCE
	return false

static func incap_reason(statuses: Array) -> String:
	for s in statuses:
		if s.kind == StatusEffect.Kind.SLEEP:
			return "沉睡中"
	return "麻痺"

static func prevents_casting(statuses: Array) -> bool:
	for s in statuses:
		if s.kind == StatusEffect.Kind.SILENCE:
			return true
	return false

# 受擊清眠：回傳「移除所有 SLEEP 後」的新陣列；呼叫端重指派 target.statuses。
static func cleared_on_hit(statuses: Array) -> Array:
	var out: Array[StatusEffect] = []
	for s in statuses:
		if s.kind != StatusEffect.Kind.SLEEP:
			out.append(s)
	return out

static func persists_overworld(e: StatusEffect) -> bool:
	return e.kind == StatusEffect.Kind.POISON

static func keep_persisting(statuses: Array) -> Array:
	var out: Array[StatusEffect] = []
	for s in statuses:
		if persists_overworld(s):
			out.append(s)
	return out

static func is_buff(e: StatusEffect) -> bool:
	return e.kind == StatusEffect.Kind.STAT_MOD and e.amount > 0

static func label(e: StatusEffect) -> String:
	match e.kind:
		StatusEffect.Kind.STAT_MOD:
			var arrow := "↑" if e.amount > 0 else "↓"
			return arrow + _stat_abbrev(e.stat)
		StatusEffect.Kind.POISON:
			return "毒"
		StatusEffect.Kind.BURN:
			return "燒"
		StatusEffect.Kind.SLEEP:
			return "睡"
		StatusEffect.Kind.PARALYSIS:
			return "痺"
		StatusEffect.Kind.SILENCE:
			return "默"
	return "?"

static func color(e: StatusEffect) -> Color:
	match e.kind:
		StatusEffect.Kind.STAT_MOD:
			return Color(0.4, 0.9, 0.4) if e.amount > 0 else Color(0.95, 0.4, 0.4)
		StatusEffect.Kind.POISON:
			return Color(0.55, 0.85, 0.35)
		StatusEffect.Kind.BURN:
			return Color(0.95, 0.55, 0.25)
		StatusEffect.Kind.SLEEP, StatusEffect.Kind.PARALYSIS:
			return Color(0.6, 0.6, 0.95)
		StatusEffect.Kind.SILENCE:
			return Color(0.8, 0.6, 0.9)
	return Color.WHITE

static func _stat_abbrev(stat: int) -> String:
	match stat:
		StatusEffect.Stat.ATTACK:
			return "ATK"
		StatusEffect.Stat.ARMOR:
			return "DEF"
		StatusEffect.Stat.ACCURACY:
			return "ACC"
	return "?"
