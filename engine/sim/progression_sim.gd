class_name ProgressionSim
extends Object
# XP 經濟/節奏模擬：從開場隊伍出發，反覆挑「打得贏的最高 XP 效率遭遇」打、發真實 XP、場間全休。
# 本檔聚焦純彙整 helper（可單測）；驅動迴圈見 run()。

const _ATTRS := ["might", "intellect", "personality", "endurance", "speed", "accuracy", "luck"]

static func party_min_level(party: Party) -> int:
	var lo := 1 << 30
	for m in party.members:
		lo = mini(lo, m.level)
	return lo if not party.members.is_empty() else 0

static func party_avg_level(party: Party) -> float:
	if party.members.is_empty():
		return 0.0
	var total := 0
	for m in party.members:
		total += m.level
	return float(total) / float(party.members.size())

static func full_rest(party: Party) -> void:
	for m in party.members:
		m.condition = Character.Condition.OK
		m.hp = m.hp_max
		m.sp = m.sp_max
		m.statuses = []

# 仿 main.gd._grant_rewards：清醒成員均分 total_xp_reward，回傳總升級次數。
static func grant_fight_xp(party: Party, total_xp_reward: int) -> int:
	var conscious: Array = []
	for c in party.members:
		if c.is_conscious():
			conscious.append(c)
	if conscious.is_empty():
		return 0
	var share := int(total_xp_reward / float(conscious.size()))
	var levels := 0
	for c in conscious:
		levels += Leveling.grant_xp(c, share)
	return levels

static func fights_per_level(level_before_each_fight: Array) -> Dictionary:
	var out := {}
	for lvl in level_before_each_fight:
		var k := int(lvl)
		out[k] = int(out.get(k, 0)) + 1
	return out

static func clone_party(party: Party) -> Party:
	var p := Party.new()
	for m in party.members:
		var c := Character.new()
		c.name = m.name
		c.char_class = m.char_class
		c.level = m.level
		c.hp_max = m.hp_max
		c.sp_max = m.sp_max
		for a in _ATTRS:
			c.set(a, m.get(a))
		c.known_spells = m.known_spells.duplicate()
		c.hp = c.hp_max
		c.sp = c.sp_max
		c.condition = Character.Condition.OK
		c.statuses = []
		p.members.append(c)
	return p
