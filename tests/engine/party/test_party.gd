extends GutTest

func _char(condition: int) -> Character:
	var c := Character.new()
	c.condition = condition
	return c

func test_get_member_bounds():
	var p := Party.new()
	p.members = [_char(Character.Condition.OK)]
	assert_not_null(p.get_member(0))
	assert_null(p.get_member(-1))
	assert_null(p.get_member(1))

func test_alive_members_excludes_dead_keeps_unconscious():
	var p := Party.new()
	p.members = [
		_char(Character.Condition.OK),
		_char(Character.Condition.DEAD),
		_char(Character.Condition.UNCONSCIOUS),
	]
	assert_eq(p.alive_members().size(), 2)  # OK + UNCONSCIOUS（DEAD 被濾掉）

func test_is_wiped_true_when_none_conscious():
	var p := Party.new()
	p.members = [_char(Character.Condition.UNCONSCIOUS), _char(Character.Condition.DEAD)]
	assert_true(p.is_wiped())

func test_is_wiped_false_when_any_conscious():
	var p := Party.new()
	p.members = [_char(Character.Condition.DEAD), _char(Character.Condition.OK)]
	assert_false(p.is_wiped())

func test_create_default_six_members_exactly_one_ko():
	var p := Party.create_default()
	assert_eq(p.members.size(), 6)
	var ko := 0
	for m in p.members:
		assert_ne(m.name, "", "每名成員都要有名字")
		assert_ne(m.char_class, "", "每名成員都要有職業")
		assert_gt(m.hp_max, 0, "每名成員 hp_max 要 > 0")
		if m.condition == Character.Condition.UNCONSCIOUS:
			ko += 1
	assert_eq(ko, 1, "預設隊伍恰好 1 名 UNCONSCIOUS")
