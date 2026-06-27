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
	watch_signals(layer)
	layer._action_input(KEY_1)   # 快速攻擊 1 號怪
	assert_gt(layer._log._lines.size(), 1, "攻擊後 log 應新增訊息（不只開場行）")
	assert_signal_emitted(layer, "turn_resolved")

func test_action_bar_ignored_when_not_in_action_mode():
	var layer := _begin()
	layer._mode = "spell"          # 模擬子選單開啟中
	var log_before := layer._log._lines.size()
	layer._on_action_selected("defend")
	assert_eq(layer._mode, "spell", "行動列在非 action 模式應被忽略")
	assert_eq(layer._log._lines.size(), log_before, "未執行防禦行動")

class _StageSpy extends CombatStage:
	var attacked: Array = []
	func play_attack(monster) -> void:
		attacked.append(monster)

# 怪較快 → begin() 的 _resolve 先跑怪物回合；可選讓怪入睡以走 try_skip_turn 分支。
func _layer_with_spy(asleep: bool) -> Array:
	var cam := Camera3D.new(); add_child_autofree(cam)
	var hero := _char("Hero", 30, 1)            # 慢 → 怪先動
	var mon := _monster("M", 30, 99)            # 快
	if asleep:
		# 鏡射 engine/combat/combat_system.gd 對 inflict 的建構：from_data(kind, stat, magnitude, potency, duration)
		mon.statuses.append(StatusCatalog.from_data(StatusEffect.Kind.SLEEP, -1, 0, 0, 5))
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), RandomNumberGenerator.new())
	var layer := CombatLayer.new(); add_child_autofree(layer)
	# 注意：begin() 內 _build() 以 `if _stage == null` 一次建好所有子元件，
	# 不能在 begin 前塞 spy（會跳過子元件建立）。故先正常 begin，再換上 spy 並 rebuild。
	layer.begin(cs, cam)
	var spy := _StageSpy.new(); add_child_autofree(spy)
	spy.setup(cam); spy.rebuild(cs.monsters)
	layer._stage = spy
	return [layer, spy, mon]

func test_monster_turn_calls_play_attack():
	var bundle := _layer_with_spy(false)
	var layer: CombatLayer = bundle[0]
	var spy = bundle[1]
	var mon = bundle[2]
	layer._defend()   # 隊員行動 → _resolve 推進到怪物回合 → play_attack
	assert_true(spy.attacked.has(mon), "怪物行動前對行動怪呼叫 play_attack")

func test_skipped_monster_does_not_call_play_attack():
	var bundle := _layer_with_spy(true)   # 怪入睡
	var layer: CombatLayer = bundle[0]
	var spy = bundle[1]
	layer._defend()   # 隊員行動 → _resolve 遇睡怪走 try_skip_turn → 不 play_attack
	assert_true(spy.attacked.is_empty(), "被跳過的怪不呼叫 play_attack")
