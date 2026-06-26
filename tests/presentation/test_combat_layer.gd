extends GutTest

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev

func _char(name: String, hp: int, might: int, acc: int, speed: int) -> Character:
	var c := Character.new()
	c.name = name
	c.hp = hp
	c.hp_max = hp
	c.might = might
	c.accuracy = acc
	c.speed = speed
	c.condition = Character.Condition.OK
	return c

func _monster(name: String, hp: int, might: int, acc: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = name
	m.hp = hp
	m.hp_max = hp
	m.might = might
	m.armor = 0
	m.accuracy = acc
	m.speed = speed
	m.xp_reward = 10
	m.gold_reward = 5
	return m

func _party(c: Character) -> Party:
	var p := Party.new()
	var ms: Array[Character] = [c]
	p.members = ms
	return p

func _monsters(m: Monster) -> Array[Monster]:
	var out: Array[Monster] = [m]
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_turn_resolved_emitted_after_party_action():
	var cam := Camera3D.new()
	add_child_autofree(cam)
	var layer := CombatLayer.new()
	add_child_autofree(layer)
	var hero := _char("Hero", 100, 5, 1000, 50)   # 快、必中
	var mon := _monster("Mon", 100, 1, 1, 1)       # 撐得住一擊 → 戰鬥未結束
	var cs := CombatSystem.new(_party(hero), _monsters(mon), _rng(1))
	layer.begin(cs, cam)
	assert_true(cs.is_party_turn())
	watch_signals(layer)
	layer._unhandled_input(_key(KEY_1))            # 攻擊 1 號敵人
	assert_signal_emitted(layer, "turn_resolved")

func test_turn_resolved_emitted_after_monster_first_opening():
	# 怪物較快先動：begin() 直接呼叫 _resolve() 跑怪物開場回合，
	# 此路徑應仍在最後 emit turn_resolved，讓 HUD 即時刷新血條/數字。
	var cam := Camera3D.new()
	add_child_autofree(cam)
	var layer := CombatLayer.new()
	add_child_autofree(layer)
	var hero := _char("Hero", 100, 1, 1, 1)        # 慢、撐得住開場一擊
	var mon := _monster("Mon", 100, 5, 1000, 50)   # 快、必中 → 先動
	var cs := CombatSystem.new(_party(hero), _monsters(mon), _rng(1))
	watch_signals(layer)
	layer.begin(cs, cam)
	assert_signal_emitted(layer, "turn_resolved")
