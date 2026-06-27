extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

var _def: QuestDef

func _gs() -> Node:
	var gs = GameStateScript.new()
	add_child_autofree(gs)
	gs.quest_resolver = Callable(self, "_resolve")
	return gs

func _resolve(id) -> QuestDef:
	return _def if id == "q" else null

func before_each():
	_def = QuestDef.parse({
		"id": "q", "title": "哥布林的威脅",
		"stages": [
			{"type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "前往"},
			{"type": "kill", "monster": "goblin", "count": 2, "desc": "擊敗"},
			{"type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 100, "items": ["potion"]},
	})

func test_accept_sets_active_stage0_when_nothing_done():
	var gs = _gs()
	assert_true(gs.is_quest_inactive("q"))
	gs.accept_quest("q")
	assert_true(gs.is_quest_active("q"))
	assert_eq(gs.quest_stage("q"), 0)

func test_accept_idempotent():
	var gs = _gs()
	gs.accept_quest("q")
	gs.accept_quest("q")
	assert_eq(gs.quests.size(), 1)

func test_notify_kill_increments_tally_without_quest():
	var gs = _gs()
	gs.notify_kill("goblin")
	assert_eq(int(gs.kill_counts.get("goblin", 0)), 1)

func test_full_flow_completes_and_rewards():
	var gs = _gs()
	gs.accept_quest("q")
	assert_eq(gs.quest_stage("q"), 0)            # reach
	gs.mark_explored("wild_ne", Vector2i(3, 3), 5, 5)
	gs.notify_enter("wild_ne", Vector2i(3, 3))
	assert_eq(gs.quest_stage("q"), 1)            # kill
	gs.notify_kill("goblin")
	gs.notify_kill("goblin")
	assert_eq(gs.quest_stage("q"), 2)            # collect
	gs.inventory.add("lucky_charm", 1)
	gs.refresh_collect()
	assert_eq(gs.quest_stage("q"), 3)            # talk
	var gold_before: int = gs.gold
	gs.advance_quest("q")
	assert_true(gs.is_quest_done("q"))
	assert_eq(gs.gold, gold_before + 100)
	assert_eq(gs.inventory.count_of("potion"), 3)  # 起始 2 + 獎勵 1

func test_kill_before_accept_is_credited_on_accept():
	# 修復重點：先殺哥布林（無任務），再接任務 → 接取追認、不卡死
	var gs = _gs()
	gs.notify_kill("goblin")
	gs.notify_kill("goblin")
	gs.mark_explored("wild_ne", Vector2i(3, 3), 5, 5)   # reach（stage0）也先滿足以驗連鎖
	gs.accept_quest("q")
	assert_eq(gs.quest_stage("q"), 2)   # reach→kill 皆追認，停在 collect（未撿）

func test_all_done_before_accept_lands_on_talk():
	var gs = _gs()
	gs.notify_kill("goblin")
	gs.notify_kill("goblin")
	gs.inventory.add("lucky_charm", 1)
	gs.mark_explored("wild_ne", Vector2i(3, 3), 5, 5)
	gs.accept_quest("q")
	assert_eq(gs.quest_stage("q"), 3)   # 全追認、落在回報

func test_quests_changed_emitted_on_accept():
	var gs = _gs()
	watch_signals(gs)
	gs.accept_quest("q")
	assert_signal_emitted(gs, "quests_changed")

func test_accept_without_resolver_is_noop():
	var gs = _gs()
	gs.quest_resolver = Callable()
	gs.accept_quest("q")
	assert_true(gs.is_quest_inactive("q"))

func test_xp_reward_granted_to_conscious_member_on_turn_in():
	var gs = _gs()
	var c := Character.new()
	c.condition = Character.Condition.OK   # 清醒
	c.level = 1
	c.experience = 0
	var p := Party.new(); p.members = [c]
	gs.party = p
	_def.rewards["xp"] = 30
	# 先把目標都做完，接取追認到 talk 階段
	gs.notify_kill("goblin"); gs.notify_kill("goblin")
	gs.inventory.add("lucky_charm", 1)
	gs.mark_explored("wild_ne", Vector2i(3, 3), 5, 5)
	gs.accept_quest("q")
	assert_eq(gs.quest_stage("q"), 3)   # 追認到回報階段
	gs.advance_quest("q")               # 回報 → done → 發獎（XP 在此刻才給）
	assert_true(gs.is_quest_done("q"))
	assert_eq(c.experience, 30)         # 30 < xp_for_level(1)=100 → 不升級、exp=30
