class_name Party
extends RefCounted

var members: Array[Character] = []

func get_member(i: int) -> Character:
	if i < 0 or i >= members.size():
		return null
	return members[i]

func alive_members() -> Array[Character]:
	var out: Array[Character] = []
	for m in members:
		if m.is_alive():
			out.append(m)
	return out

func is_wiped() -> bool:
	for m in members:
		if m.is_conscious():
			return false
	return true

# 過渡骨架隊伍：6 人、含 1 名 KO（Marcus）。職業/名字/起始等級固定；
# 所有屬性與 hp_max/sp_max 由 ClassCatalog 衍生（職業差異化的唯一來源）。
static func create_default() -> Party:
	var roster := [
		{"name": "Gerard", "class": "Knight", "level": 3, "condition": Character.Condition.OK},
		{"name": "Cordelia", "class": "Paladin", "level": 3, "condition": Character.Condition.OK},
		{"name": "Sira", "class": "Archer", "level": 2, "condition": Character.Condition.OK},
		{"name": "Marcus", "class": "Cleric", "level": 3, "condition": Character.Condition.UNCONSCIOUS},
		{"name": "Cassia", "class": "Sorcerer", "level": 2, "condition": Character.Condition.OK},
		{"name": "Dunkan", "class": "Robber", "level": 2, "condition": Character.Condition.OK},
	]
	var p := Party.new()
	for r in roster:
		p.members.append(_make(r["name"], r["class"], r["level"], r["condition"]))
	return p

static func _make(name: String, char_class: String, level: int, condition: int) -> Character:
	var c := Character.new()
	c.name = name
	c.char_class = char_class
	c.level = level
	var s := ClassCatalog.stats_at_level(char_class, level)
	c.might = s["might"]
	c.intellect = s["intellect"]
	c.personality = s["personality"]
	c.endurance = s["endurance"]
	c.speed = s["speed"]
	c.accuracy = s["accuracy"]
	c.luck = s["luck"]
	c.hp_max = s["hp_max"]
	c.sp_max = s["sp_max"]
	c.sp = c.sp_max
	c.condition = condition
	c.hp = 0 if condition == Character.Condition.UNCONSCIOUS else c.hp_max
	return c
