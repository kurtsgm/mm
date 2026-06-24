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

# 過渡骨架隊伍（M3 不平衡）：6 人、含 1 名 KO、HP/SP 涵蓋滿／半／空以驗證 HUD 渲染。
# 真正的角色創建與存檔屬後續／M5。
static func create_default() -> Party:
	var p := Party.new()
	p.members = [
		_make("Gerard",   "Knight",   3, 28, 28, 0,  0,  Character.Condition.OK),
		_make("Cordelia", "Paladin",  3, 18, 26, 4,  8,  Character.Condition.OK),
		_make("Sira",     "Archer",   2, 14, 20, 6,  10, Character.Condition.OK),
		_make("Marcus",   "Cleric",   3, 0,  22, 9,  14, Character.Condition.UNCONSCIOUS),
		_make("Cassia",   "Sorcerer", 2, 12, 16, 12, 12, Character.Condition.OK),
		_make("Dunkan",   "Robber",   2, 16, 18, 0,  0,  Character.Condition.OK),
	]
	return p

static func _make(name: String, char_class: String, level: int, hp: int, hp_max: int, sp: int, sp_max: int, condition: int) -> Character:
	var c := Character.new()
	c.name = name
	c.char_class = char_class
	c.level = level
	c.hp = hp
	c.hp_max = hp_max
	c.sp = sp
	c.sp_max = sp_max
	c.condition = condition
	# 骨架圍值（固定即可；平衡與差異化屬內容期）
	c.might = 15
	c.intellect = 12
	c.personality = 12
	c.endurance = 14
	c.speed = 13
	c.accuracy = 13
	c.luck = 11
	return c
