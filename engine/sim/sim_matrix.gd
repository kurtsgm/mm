class_name SimMatrix
extends Object
# 掃描「遭遇 × 等級」，每格跑 N 場蒙地卡羅，彙整成難度表 rows。

static func run_cell(encounter_id: String, level: int, n: int, base_seed: int, catalog = ClassCatalog) -> Dictionary:
	var defs := Bestiary.group_defs_for(encounter_id)
	var wins := 0
	var rounds_sum := 0.0
	var deaths_sum := 0.0
	var hp_pct_win_sum := 0.0
	var timeouts := 0
	for run_index in n:
		var party := SimPartyBuilder.build(level, catalog)
		var mons: Array[Monster] = []
		for d in defs:
			mons.append(Monster.from_def(d))
		var rng := RandomNumberGenerator.new()
		rng.seed = _cell_seed(base_seed, encounter_id, level, run_index)
		var out := BattleRunner.run(party, mons, rng)
		if out["timeout"]:
			timeouts += 1
		if out["result"] == CombatSystem.Result.VICTORY:
			wins += 1
			rounds_sum += float(out["rounds"])
			hp_pct_win_sum += float(out["hp_pct"])
		deaths_sum += float(out["deaths"])
	return {
		"encounter": encounter_id,
		"level": level,
		"win_rate": float(wins) / float(n) if n > 0 else 0.0,
		"avg_rounds": rounds_sum / float(wins) if wins > 0 else 0.0,
		"avg_deaths": deaths_sum / float(n) if n > 0 else 0.0,
		"avg_hp_pct_on_win": hp_pct_win_sum / float(wins) if wins > 0 else 0.0,
		"timeouts": timeouts,
		"n": n,
	}

static func run_all(levels: Array, n: int, base_seed: int, catalog = ClassCatalog) -> Array:
	var rows: Array = []
	for enc in Bestiary.all_ids():
		for lvl in levels:
			rows.append(run_cell(String(enc), int(lvl), n, base_seed, catalog))
	return rows

static func _cell_seed(base: int, encounter_id: String, level: int, run_index: int) -> int:
	return base + hash(encounter_id) * 1000003 + level * 7919 + run_index
