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

static func _monsters_for(encounter_id: String, bestiary) -> Array[Monster]:
	var mons: Array[Monster] = []
	for d in bestiary.group_defs_for(encounter_id):
		mons.append(Monster.from_def(d))
	return mons

static func _xp_total(encounter_id: String, bestiary) -> int:
	var total := 0
	for d in bestiary.group_defs_for(encounter_id):
		total += d.xp_reward
	return total

static func estimate_encounter(party: Party, encounter_id: String, trials: int, base_seed: int, bestiary = TierBestiary) -> Dictionary:
	var wins := 0
	var rounds_sum := 0.0
	for t in trials:
		var clone := clone_party(party)
		var mons := _monsters_for(encounter_id, bestiary)
		var rng := RandomNumberGenerator.new()
		rng.seed = base_seed + hash(encounter_id) * 1000003 + t
		var out := BattleRunner.run(clone, mons, rng)
		if out["result"] == CombatSystem.Result.VICTORY:
			wins += 1
			rounds_sum += float(out["rounds"])
	var win_rate := float(wins) / float(trials) if trials > 0 else 0.0
	var avg_rounds := rounds_sum / float(wins) if wins > 0 else 0.0
	var xp_total := _xp_total(encounter_id, bestiary)
	var efficiency := (float(xp_total) / avg_rounds) if avg_rounds > 0.0 else 0.0
	return {"win_rate": win_rate, "avg_rounds": avg_rounds, "xp_total": xp_total, "efficiency": efficiency}

static func run(target_level: int, base_seed: int, trials := 12, win_threshold := 0.7, max_fights := 500, bestiary = TierBestiary) -> Dictionary:
	var party := Party.create_default()
	full_rest(party)
	var fights: Array = []
	var levels_before: Array = []
	var reached := false
	var fight_seed := base_seed
	while fights.size() < max_fights:
		if party_min_level(party) >= target_level:
			reached = true
			break
		# 選「可贏（win_rate ≥ 門檻）中 XP 效率最高」的遭遇
		var best_id := ""
		var best_eff := 0.0
		var best_xp := 0
		for enc in bestiary.all_ids():
			var est := estimate_encounter(party, String(enc), trials, fight_seed, bestiary)
			if est["win_rate"] >= win_threshold and est["efficiency"] > best_eff:
				best_eff = est["efficiency"]
				best_id = String(enc)
				best_xp = int(est["xp_total"])
		if best_id == "":
			break   # 無可贏遭遇 → 卡住
		var lvl_before := party_min_level(party)
		# 真打一場
		var mons := _monsters_for(best_id, bestiary)
		var rng := RandomNumberGenerator.new()
		rng.seed = fight_seed
		fight_seed += 1
		var out := BattleRunner.run(party, mons, rng)
		var victory: bool = out["result"] == CombatSystem.Result.VICTORY
		if victory:
			grant_fight_xp(party, best_xp)
		full_rest(party)   # 場間全休（聚焦 XP 節奏，非連戰耗損）
		levels_before.append(lvl_before)
		fights.append({
			"index": fights.size(),
			"encounter": best_id,
			"party_level": lvl_before,
			"xp_total": best_xp,
			"victory": victory,
			"avg_level": party_avg_level(party),
		})
	return {
		"fights": fights,
		"fights_per_level": fights_per_level(levels_before),
		"reached_target": reached,
		"final_min_level": party_min_level(party),
		"final_avg_level": party_avg_level(party),
		"target_level": target_level,
		"win_threshold": win_threshold,
	}
