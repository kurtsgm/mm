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

func test_accept_sets_active_stage0():
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

func test_reach_then_kill_then_collect_then_talk_completes_and_rewards():
	var gs = _gs()
	gs.accept_quest("q")
	gs.notify_enter("wild_ne", Vector2i(3, 3))
	assert_eq(gs.quest_stage("q"), 1)
	gs.notify_kill("goblin")
	gs.notify_kill("goblin")
	assert_eq(gs.quest_stage("q"), 2)
	gs.inventory.add("lucky_charm", 1)
	gs.refresh_collect()
	assert_eq(gs.quest_stage("q"), 3)
	var gold_before: int = gs.gold
	gs.advance_quest("q")
	assert_true(gs.is_quest_done("q"))
	assert_eq(gs.gold, gold_before + 100)
	assert_eq(gs.inventory.count_of("potion"), 3)  # 起始 2 + 獎勵 1

func test_quests_changed_emitted_on_progress():
	var gs = _gs()
	watch_signals(gs)
	gs.accept_quest("q")
	assert_signal_emitted(gs, "quests_changed")

func test_notify_ignores_unknown_active_quest_without_resolver():
	var gs = _gs()
	gs.quest_resolver = Callable()  # 無 resolver
	gs.accept_quest("q")            # 無 def → 不接
	assert_true(gs.is_quest_inactive("q"))
