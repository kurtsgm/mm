extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")
const DIALOGUES := [
	"qg_oak_guard", "qg_oak_lord", "qg_oak_taxman", "qg_margo", "qg_dorn",
	"oak_caravan_master", "oak_inquisitor_omen", "nav_echo_nest",
	"qg_nw_messenger", "qg_ne_scout",
]

func _state():
	var gs = GameStateScript.new()
	add_child_autofree(gs)
	gs.quest_resolver = Callable(QuestCatalog, "load_quest")
	return gs

func _runner(id: String, gs) -> DialogueRunner:
	return DialogueRunner.new(DialogueCatalog.load_dialogue(id), gs)

func _choice(r: DialogueRunner, target) -> Dictionary:
	for choice in r.available_choices():
		if choice.get("goto") == target:
			return choice
	return {}

func _choose(r: DialogueRunner, target) -> void:
	var choice := _choice(r, target)
	assert_false(choice.is_empty(), "可前往 %s" % str(target))
	if not choice.is_empty():
		r.choose(choice)

func test_all_oak_dialogue_images_load_real_assets():
	for id in DIALOGUES:
		var d := DialogueCatalog.load_dialogue(id)
		assert_not_null(d, id)
		if d == null:
			continue
		for nid in d.nodes:
			var image_id := String(d.node(nid).get("image", ""))
			assert_true(SceneImageCatalog.has_image(image_id), "%s/%s 圖片已登記" % [id, nid])
			var tex := SceneImageCatalog.get_texture(image_id)
			# catalog 的純色 fallback 不算實際交付。
			assert_true(tex is CompressedTexture2D, "%s/%s 讀到實圖" % [id, nid])

func test_levy_all_three_dialogue_routes_complete_and_reward_once():
	for route in ["outwit", "bribe", "bully"]:
		var gs = _state()
		var lord := _runner("qg_oak_lord", gs)
		assert_true(_choice(lord, "brief").is_empty(), "哥布林任務完成前不開徵糧任務")
		QuestFlow.simulate(gs, QuestCatalog.load_quest("goblin_menace"), "goblin_menace")
		gs.gold = 50 if route == "bribe" else 0
		_choose(lord, "brief")
		_choose(lord, "leverage")
		_choose(lord, null)
		assert_eq(gs.quest_stage("oak_levy"), 0)
		var taxman := _runner("qg_oak_taxman", gs)
		if route == "outwit":
			gs.flags.erase("levy_leverage")
			assert_true(_choice(taxman, "opt_bribe").is_empty(), "零金不可收買")
			assert_true(_choice(taxman, "opt_bully").is_empty(), "無把柄不可威嚇")
		_choose(taxman, "opt_" + route)
		_choose(taxman, null)
		assert_eq(gs.quest_stage("oak_levy"), 1)
		assert_eq(gs.gold, 0, "僅收買分支支付 50 金")
		lord = _runner("qg_oak_lord", gs)
		_choose(lord, "turn_" + route)
		_choose(lord, "reward")
		_choose(lord, "warning")
		_choose(lord, null)
		assert_true(gs.is_quest_done("oak_levy"))
		assert_eq(gs.gold, 120)
		var count_before: int = gs.inventory.instances().size()
		lord = _runner("qg_oak_lord", gs)
		assert_true(_choice(lord, "turn_" + route).is_empty())
		_choose(lord, "done")
		_choose(lord, null)
		assert_eq(gs.gold, 120, "重談不重複領金")
		assert_eq(gs.inventory.instances().size(), count_before, "重談不重複領甲")

func test_antidote_accepts_from_both_conversation_entries():
	for through_patient in [false, true]:
		var gs = _state()
		var r := _runner("qg_margo", gs)
		if through_patient:
			_choose(r, "patient")
		_choose(r, "accepted")
		_choose(r, null)
		gs.inventory.add("swamp_herb", 3)
		gs.refresh_collect()
		r = _runner("qg_margo", gs)
		_choose(r, "turned_in")
		_choose(r, null)
		assert_true(gs.is_quest_done("oak_antidote"))
		assert_eq(gs.inventory.count_of("antidote"), 2)
		r = _runner("qg_margo", gs)
		assert_true(_choice(r, "patient").is_empty(), "治癒後不再重播病危求助")
		assert_true(_choice(r, "turned_in").is_empty())
		_choose(r, "thanks")
		_choose(r, null)
		assert_eq(gs.inventory.count_of("antidote"), 2)

func test_echo_unlocks_dorn_only_after_witnessing_event():
	for inspect_companions in [false, true]:
		var gs = _state()
		assert_true(_choice(_runner("qg_dorn", gs), "probe").is_empty())
		var echo := _runner("nav_echo_nest", gs)
		var approach: Dictionary = echo.available_choices()[int(inspect_companions)]
		echo.choose(approach)
		assert_true(gs.has_flag("nav_echo_seen"), "靠近或退開都會聽見殘響")
		if inspect_companions:
			_choose(echo, "companions")
		_choose(echo, "aftermath")
		_choose(echo, null)
		assert_true(echo.is_finished())
		assert_false(_choice(_runner("qg_dorn", gs), "probe").is_empty())

func test_omen_choices_rejoin_and_unlock_town_reactions():
	for response in ["bounty", "question", "silence"]:
		var gs = _state()
		for id in ["qg_oak_guard", "qg_oak_lord", "qg_margo", "qg_dorn"]:
			assert_true(_choice(_runner(id, gs), "after_omen").is_empty())
		var r := _runner("oak_inquisitor_omen", gs)
		_choose(r, "greeting")
		_choose(r, response)
		_choose(r, "departure")
		_choose(r, null)
		assert_true(r.is_finished())
		for id in ["qg_oak_guard", "qg_oak_lord", "qg_margo", "qg_dorn"]:
			assert_false(_choice(_runner(id, gs), "after_omen").is_empty())
		assert_eq(gs.gold, 0, "事件選擇僅風味，不發獎勵")

func test_caravan_unlock_has_repeatable_directions():
	var gs = _state()
	assert_true(TravelCatalog.unlocked_destinations(gs, "oak_caravan").is_empty())
	var r := _runner("oak_caravan_master", gs)
	_choose(r, "unlocked")
	_choose(r, null)
	assert_eq(TravelCatalog.unlocked_destinations(gs, "oak_caravan").size(), 1)
	r = _runner("oak_caravan_master", gs)
	assert_true(_choice(r, "unlocked").is_empty())
	_choose(r, "camp")
	_choose(r, "root")
	_choose(r, "travel")
	_choose(r, null)
	assert_eq(gs.gold, 0, "問路不代替搭車、不收車資")

func test_message_content_can_be_delivered_and_not_claimed_twice():
	var gs = _state()
	var r := _runner("qg_nw_messenger", gs)
	_choose(r, "accepted")
	_choose(r, null)
	r = _runner("qg_ne_scout", gs)
	_choose(r, "received")
	_choose(r, null)
	assert_true(gs.is_quest_done("wild_message"))
	assert_eq(gs.gold, 40)
	r = _runner("qg_ne_scout", gs)
	assert_true(_choice(r, "received").is_empty())
	_choose(r, "done_thanks")
	_choose(r, null)
	assert_eq(gs.gold, 40)
