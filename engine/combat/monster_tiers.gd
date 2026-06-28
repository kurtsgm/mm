class_name MonsterTiers
extends Object
# 公式化原型縮放：10 tier × 4 archetype。每 archetype 給 base + per-tier step（線性）。
# 數字為初值，最終由模擬器調校。怪物 level = 10*tier（tier 10 → 100 封頂）。
# 皆落在現有 Monster 戰鬥模型內（近戰 + inflict_* 異常）。

# 每 archetype 的縮放表：base/step 對應 hp_max/might/armor/speed/accuracy/luck/xp。
const _A := {
	"brute":      {"hp": [40, 45], "might": [12, 11], "armor": [2, 2], "speed": [6, 1],  "acc": [9, 2],  "luck": [2, 1], "xp": [30, 40], "count": 1},
	"skirmisher": {"hp": [22, 28], "might": [9, 8],   "armor": [1, 1], "speed": [12, 3], "acc": [13, 3], "luck": [4, 2], "xp": [18, 26], "count": 2},
	"swarm":      {"hp": [10, 12], "might": [6, 6],   "armor": [0, 1], "speed": [9, 2],  "acc": [8, 2],  "luck": [2, 1], "xp": [8, 12],  "count": 4},
	"ailment":    {"hp": [14, 18], "might": [5, 6],   "armor": [0, 1], "speed": [9, 2],  "acc": [9, 2],  "luck": [3, 1], "xp": [14, 20], "count": 2},
}
# ailment 中毒縮放
const _POISON_POTENCY := [2, 2]   # base, step
const _POISON_DURATION := 3
const _POISON_CHANCE := 0.4

static func archetypes() -> Array:
	return ["brute", "skirmisher", "swarm", "ailment"]

static func group_count(archetype: String) -> int:
	if not _A.has(archetype):
		return 1
	return int(_A[archetype]["count"])

static func _scaled(spec: Array, tier: int) -> int:
	return int(spec[0]) + (tier - 1) * int(spec[1])

static func make_def(tier: int, archetype: String) -> MonsterDef:
	var d := MonsterDef.new()
	if not _A.has(archetype):
		return d
	var a: Dictionary = _A[archetype]
	d.id = "t%d_%s" % [tier, archetype]
	d.display_name = "%s T%d" % [archetype, tier]
	d.level = mini(10 * tier, 100)
	d.hp_max = _scaled(a["hp"], tier)
	d.might = _scaled(a["might"], tier)
	d.armor = _scaled(a["armor"], tier)
	d.speed = _scaled(a["speed"], tier)
	d.accuracy = _scaled(a["acc"], tier)
	d.luck = _scaled(a["luck"], tier)
	d.xp_reward = _scaled(a["xp"], tier)
	d.gold_reward = _scaled(a["xp"], tier)
	if archetype == "ailment":
		d.inflict_kind = StatusEffect.Kind.POISON
		d.inflict_potency = _scaled(_POISON_POTENCY, tier)
		d.inflict_duration = _POISON_DURATION
		d.inflict_chance = _POISON_CHANCE
	return d
