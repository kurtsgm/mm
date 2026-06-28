class_name TierBestiary
extends Object
# 遭遇提供者，介面對齊 Bestiary（all_ids/group_defs_for），但遭遇由 MonsterTiers 公式產生。
# 遭遇 id 形如 t{tier}_{archetype}，群大小 = MonsterTiers.group_count(archetype)。

const TIER_COUNT := 10

static func all_ids() -> Array:
	var out: Array = []
	for t in range(1, TIER_COUNT + 1):
		for arch in MonsterTiers.archetypes():
			out.append("t%d_%s" % [t, arch])
	return out

static func _parse(id: String) -> Dictionary:
	# "t3_swarm" -> {tier:3, arch:"swarm"}；非法回 {}
	if not id.begins_with("t"):
		return {}
	var us := id.find("_")
	if us < 2:
		return {}
	var tier := int(id.substr(1, us - 1))
	var arch := id.substr(us + 1)
	if tier < 1 or tier > TIER_COUNT or not MonsterTiers.archetypes().has(arch):
		return {}
	return {"tier": tier, "arch": arch}

static func group_defs_for(id: String) -> Array[MonsterDef]:
	var out: Array[MonsterDef] = []
	var p := _parse(id)
	if p.is_empty():
		return out
	var def := MonsterTiers.make_def(int(p["tier"]), String(p["arch"]))
	for i in MonsterTiers.group_count(String(p["arch"])):
		out.append(def)
	return out
