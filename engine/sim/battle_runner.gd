class_name BattleRunner
extends Object
# 用中等啟發式 policy 把一場戰鬥跑到底，回傳結果摘要。怪物 AI 用引擎內建 monster_act()。

const MAX_ACTIONS := 2000   # 退化保護閥；正常戰鬥遠在此之下收斂

static func run(party: Party, monsters: Array[Monster], rng: RandomNumberGenerator) -> Dictionary:
	var cs := CombatSystem.new(party, monsters, rng)
	var actions := 0
	while not cs.is_over():
		actions += 1
		if actions > MAX_ACTIONS:
			return _outcome(cs, true)
		if not cs.try_skip_turn().is_empty():   # 睡眠/麻痺被引擎自動跳過並前進
			continue
		if cs.is_party_turn():
			PartyCombatPolicy.act(cs)
		else:
			cs.monster_act()
	return _outcome(cs, false)

static func _outcome(cs: CombatSystem, timeout: bool) -> Dictionary:
	var deaths := 0
	var hp := 0
	var hp_max := 0
	for m in cs.party.members:
		hp_max += m.hp_max
		if m.is_conscious():
			hp += m.hp
		else:
			deaths += 1
	var pct := float(hp) / float(hp_max) if hp_max > 0 else 0.0
	return {
		"result": -1 if timeout else cs.result(),
		"rounds": cs.round_count,
		"deaths": deaths,
		"hp_pct": pct,
		"timeout": timeout,
	}
