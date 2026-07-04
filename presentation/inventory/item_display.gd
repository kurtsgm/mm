class_name ItemDisplay
extends Object

const _STAT_LABEL := {
	ItemStat.S.ATTACK: "攻擊", ItemStat.S.ARMOR: "防禦", ItemStat.S.MIGHT: "力量",
	ItemStat.S.INTELLECT: "智力", ItemStat.S.PERSONALITY: "魅力", ItemStat.S.ENDURANCE: "耐力",
	ItemStat.S.SPEED: "速度", ItemStat.S.ACCURACY: "命中", ItemStat.S.LUCK: "幸運",
	ItemStat.S.HP_MAX: "HP上限", ItemStat.S.SP_MAX: "SP上限",
}

static func stat_label(stat: int) -> String:
	return String(_STAT_LABEL.get(stat, ItemStat.to_name(stat)))

static func colored_name(inst: ItemInstance) -> String:
	return "[color=#%s]%s[/color]" % [Quality.color(inst.quality).to_html(false), inst.display_name()]

static func detail_lines(inst: ItemInstance) -> Array:
	var lines: Array = []
	var def := inst.base_def()
	if def != null and def.attack != 0:
		lines.append("基礎攻擊 %d" % def.attack)
	if def != null and def.armor != 0:
		lines.append("基礎防禦 %d" % def.armor)
	# 逐條詞綴（unique 直接列 mods）
	for a in inst.affixes:
		for stat in a.get("mods", {}):
			lines.append("%s +%d" % [stat_label(stat), int(a["mods"][stat])])
		var oh: Dictionary = a.get("on_hit", {})
		if not oh.is_empty():
			lines.append("命中時：%d%% 施加異常" % int(round(float(oh["chance"]) * 100.0)))
	if inst.unique_id != "":
		var u := UniqueCatalog.entry(inst.unique_id)
		for stat in (u.get("mods", {}) as Dictionary):
			lines.append("%s +%d" % [stat_label(stat), int(u["mods"][stat])])
	lines.append("ilvl %d　售價 %d" % [inst.ilvl, inst.sell_value()])
	return lines
