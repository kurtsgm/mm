class_name CharacterStatusTab
extends Object

# 把一個 Character 轉成角色卡顯示文字（每行一個字串）。純函式，無副作用，好測。

const _CLASS_LABEL := {
	"Knight": "騎士", "Paladin": "聖騎士", "Archer": "弓手",
	"Cleric": "牧師", "Sorcerer": "法師", "Robber": "盜賊",
}

static func lines(c: Character) -> Array:
	var out: Array = []
	if c == null:
		out.append("（無角色）")
		return out
	var need := Leveling.xp_for_level(c.level)
	out.append("%s   %s   Lv%d" % [c.name, _class_label(c.char_class), c.level])
	out.append("經驗 %d / %d   （距下一級 %d）" % [c.experience, need, maxi(0, need - c.experience)])
	out.append("HP %d/%d    SP %d/%d" % [c.hp, c.hp_max, c.sp, c.sp_max])
	out.append("狀態：%s" % _condition_label(c.condition))
	out.append("──")
	out.append("力量 %d   智力 %d   人格 %d" % [c.might, c.intellect, c.personality])
	out.append("耐力 %d   速度 %d   精準 %d   幸運 %d" % [c.endurance, c.speed, c.accuracy, c.luck])
	out.append("──")
	out.append("攻擊 %d   防禦 %d   命中 %d" % [c.attack_power(), c.armor_value(), c.effective_accuracy()])
	out.append("──")
	out.append("狀態異常：%s" % _status_text(c.statuses))
	return out

# 結構化角色卡資料（給 widget 版 StatusView 用；與 lines() 並存）。
static func fields(c: Character) -> Dictionary:
	if c == null:
		return {}
	var need := Leveling.xp_for_level(c.level)
	var statuses: Array = []
	for s in c.statuses:
		statuses.append({"label": StatusRules.label(s), "color": StatusRules.color(s)})
	return {
		"name": c.name,
		"class_label": _class_label(c.char_class),
		"level": c.level,
		"xp": c.experience,
		"xp_need": need,
		"xp_to_next": maxi(0, need - c.experience),
		"hp": c.hp, "hp_max": c.hp_max,
		"sp": c.sp, "sp_max": c.sp_max,
		"condition_label": _condition_label(c.condition),
		"stats": {
			"might": c.might, "intellect": c.intellect, "personality": c.personality,
			"endurance": c.endurance, "speed": c.speed, "accuracy": c.accuracy, "luck": c.luck,
		},
		"attack": c.attack_power(),
		"armor": c.armor_value(),
		"accuracy_eff": c.effective_accuracy(),
		"statuses": statuses,
	}

static func _class_label(cls: String) -> String:
	return _CLASS_LABEL.get(cls, cls)

static func _condition_label(cond: int) -> String:
	match cond:
		Character.Condition.OK:
			return "正常"
		Character.Condition.UNCONSCIOUS:
			return "昏迷"
		Character.Condition.DEAD:
			return "死亡"
	return "?"

static func _status_text(statuses: Array) -> String:
	if statuses.is_empty():
		return "無"
	var parts: Array = []
	for s in statuses:
		parts.append(StatusRules.label(s))
	return "  ".join(parts)
