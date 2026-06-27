class_name StatusCatalog
extends Object

# 各 kind 的建構工廠，集中欄位設定，避免散落的手動賦值。

static func stat_mod(stat: int, amount: int, dur: int) -> StatusEffect:
	var e := StatusEffect.new()
	e.kind = StatusEffect.Kind.STAT_MOD
	e.stat = stat
	e.amount = amount
	e.remaining = dur
	return e

static func poison(potency: int, dur: int) -> StatusEffect:
	return from_data(StatusEffect.Kind.POISON, -1, 0, potency, dur)

static func burn(potency: int, dur: int) -> StatusEffect:
	return from_data(StatusEffect.Kind.BURN, -1, 0, potency, dur)

static func sleep(dur: int) -> StatusEffect:
	return from_data(StatusEffect.Kind.SLEEP, -1, 0, 0, dur)

static func paralysis(dur: int) -> StatusEffect:
	return from_data(StatusEffect.Kind.PARALYSIS, -1, 0, 0, dur)

static func silence(dur: int) -> StatusEffect:
	return from_data(StatusEffect.Kind.SILENCE, -1, 0, 0, dur)

# 資料驅動（法術/怪物 inflict 用）：依 kind 組裝，忽略不相關欄位。
static func from_data(kind: int, stat: int, amount: int, potency: int, dur: int) -> StatusEffect:
	var e := StatusEffect.new()
	e.kind = kind
	e.stat = stat
	e.amount = amount
	e.potency = potency
	e.remaining = dur
	return e
