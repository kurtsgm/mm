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
	# 順序 kill→collect→reach→talk（同 demo）：kill/collect 狀態式追認、reach 事件式、talk 對話。
	_def = QuestDef.parse({
		"id": "q", "title": "哥布林的威脅",
		"stages": [
			{"type": "kill", "targets": ["u-wild"], "desc": "擊敗"},
			{"type": "collect", "item": "lucky_charm", "count": 1, "desc": "取得"},
			{"type": "reach", "map": "wild_ne", "pos": [3, 3], "desc": "前往"},
			{"type": "talk", "desc": "回報"},
		],
		"rewards": {"gold": 100, "items": ["potion"]},
	})

func test_accept_stage0_when_nothing_done():
	var gs = _gs()
	assert_true(gs.is_quest_inactive("q"))
	gs.accept_quest("q")
	assert_true(gs.is_quest_active("q"))
	assert_eq(gs.quest_stage("q"), 0)   # kill

func test_accept_idempotent():
	var gs = _gs()
	gs.accept_quest("q"); gs.accept_quest("q")
	assert_eq(gs.quests.size(), 1)

func test_mark_defeated_records_uid():
	var gs = _gs()
	gs.mark_encounter_defeated("u-wild")
	assert_true(gs.is_defeated("u-wild"))

func test_full_flow_completes_and_rewards():
	var gs = _gs()
	gs.accept_quest("q")
	gs.notify_encounter_defeated("u-wild")
	assert_eq(gs.quest_stage("q"), 1)            # collect
	gs.inventory.add("lucky_charm", 1)
	gs.refresh_collect()
	assert_eq(gs.quest_stage("q"), 2)            # reach
	gs.notify_enter("wild_ne", Vector2i(3, 3))
	assert_eq(gs.quest_stage("q"), 3)            # talk
	var gold_before: int = gs.gold
	gs.advance_quest("q")
	assert_true(gs.is_quest_done("q"))
	assert_eq(gs.gold, gold_before + 100)
	assert_eq(gs.inventory.count_of("potion"), 3)  # 起始 2 + 獎勵 1

func test_kill_collect_before_accept_credited_stops_at_reach():
	# 殺怪+撿物在接取前（retroactive）→ 接取追認 kill+collect → 停在 reach（事件式、需踏到）
	var gs = _gs()
	gs.notify_encounter_defeated("u-wild")
	gs.inventory.add("lucky_charm", 1)
	gs.accept_quest("q")
	assert_eq(gs.quest_stage("q"), 2)   # reach（kill/collect 已追認、reach 待踏）
	gs.notify_enter("wild_ne", Vector2i(3, 3))
	assert_eq(gs.quest_stage("q"), 3)   # talk

func test_defeating_other_encounter_does_not_satisfy():
	var gs = _gs()
	gs.accept_quest("q")
	gs.notify_encounter_defeated("u-town")   # 別的遇抵（城鎮）
	assert_eq(gs.quest_stage("q"), 0)         # kill 未滿足、仍在 kill
	gs.notify_encounter_defeated("u-wild")    # 正確遇抵
	assert_eq(gs.quest_stage("q"), 1)         # → collect

func test_reach_is_map_and_cell_specific_cross_map():
	# 直接驗證跨地圖：reach 指定 wild_ne (3,3)；別圖同格/本圖別格皆不算，正確圖+格才過。
	var gs = _gs()
	gs.accept_quest("q")
	gs.notify_encounter_defeated("u-wild")
	gs.inventory.add("lucky_charm", 1); gs.refresh_collect()
	assert_eq(gs.quest_stage("q"), 2)               # reach
	gs.notify_enter("town_oak", Vector2i(3, 3))     # 別圖同格 → 不算
	assert_eq(gs.quest_stage("q"), 2)
	gs.notify_enter("wild_ne", Vector2i(1, 1))      # 本圖別格 → 不算
	assert_eq(gs.quest_stage("q"), 2)
	gs.notify_enter("wild_ne", Vector2i(3, 3))      # 正確圖+格 → 過
	assert_eq(gs.quest_stage("q"), 3)

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
	gs.notify_encounter_defeated("u-wild")
	gs.inventory.add("lucky_charm", 1)
	gs.accept_quest("q")                          # kill+collect 追認 → 停在 reach
	gs.notify_enter("wild_ne", Vector2i(3, 3))   # reach → talk
	gs.advance_quest("q")                        # 回報 → done → 發獎
	assert_true(gs.is_quest_done("q"))
	assert_eq(c.experience, 30)                  # 30 < xp_for_level(1)=40 → 不升級

func test_accept_sets_tracked_and_emits_event():
	var gs = _gs()
	watch_signals(gs)
	gs.accept_quest("q")
	assert_eq(gs.tracked_quest, "q")
	assert_signal_emitted_with_parameters(gs, "quest_event", ["接下任務：哥布林的威脅"])

func test_advance_emits_quest_event():
	var gs = _gs()
	gs.accept_quest("q")
	watch_signals(gs)
	gs.notify_encounter_defeated("u-wild")   # kill 滿足 → 推進到 collect
	assert_signal_emitted(gs, "quest_event")

func test_set_tracked_quest_active_only():
	var gs = _gs()
	gs.accept_quest("q")
	gs.set_tracked_quest("nope")     # 非進行中 → 不變
	assert_eq(gs.tracked_quest, "q")

func test_retrack_to_next_active_on_complete():
	var gs = _gs()
	gs.accept_quest("q")             # tracked = q
	# 完成 q：殺→撿→到→回報
	gs.notify_encounter_defeated("u-wild")
	gs.inventory.add("lucky_charm", 1); gs.refresh_collect()
	gs.notify_enter("wild_ne", Vector2i(3, 3))
	gs.advance_quest("q")
	assert_true(gs.is_quest_done("q"))
	assert_eq(gs.tracked_quest, "")  # 無其他進行中 → 清空

func test_retrack_picks_first_active():
	var gs = _gs()
	gs.tracked_quest = "ghost"       # 失效 id
	gs.quests["q"] = QuestSystem.initial_state()  # 直接塞一個進行中
	gs.retrack()
	assert_eq(gs.tracked_quest, "q")
