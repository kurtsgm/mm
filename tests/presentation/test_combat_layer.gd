extends GutTest

func _char(n: String, hp: int, speed: int) -> Character:
	var c := Character.new()
	c.name = n; c.hp = hp; c.hp_max = hp; c.sp = 5; c.sp_max = 5
	c.accuracy = 50; c.speed = speed; c.might = 1; c.char_class = "Knight"
	c.condition = Character.Condition.OK
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for m in members: typed.append(m)
	p.members = typed
	return p

func _monster(n: String, hp: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = n; m.hp = hp; m.hp_max = hp; m.might = 1; m.armor = 0
	m.accuracy = 1; m.speed = speed; m.xp_reward = 1; m.gold_reward = 1
	return m

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr: out.append(m)
	return out

func _begin() -> CombatLayer:
	var cam := Camera3D.new(); add_child_autofree(cam)
	var hero := _char("Hero", 30, 50)   # 快 → 先輪到隊員
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("M", 30, 1)]), RandomNumberGenerator.new())
	var layer := CombatLayer.new()
	add_child_autofree(layer)
	layer.begin(cs, cam)
	return layer

func test_begin_builds_subcomponents_without_error():
	var layer := _begin()
	assert_not_null(layer._stage)
	assert_not_null(layer._enemy)
	assert_not_null(layer._action_bar)
	assert_not_null(layer._log)
	assert_eq(layer._mode, "action")

func test_begin_builds_party_strip_with_active_highlight():
	var layer := _begin()
	assert_eq(layer._party_cards.size(), 1, "一位隊員一張卡")
	assert_true(layer._party_cards[0].is_active(), "當前行動者高亮")

func test_attack_quick_path_logs_and_progresses():
	var layer := _begin()
	layer._action_input(KEY_1)   # 快速攻擊 1 號怪
	assert_gt(layer._log._lines.size(), 1, "攻擊後 log 應新增訊息（不只開場行）")
