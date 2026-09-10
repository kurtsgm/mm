extends GutTest

func test_both_regions_replay_with_real_content():
	var maps := MapLint.load_maps()
	for id in ["oak_ruins", "oak_antidote"]:
		var region := ContentRegistry.read_json("res://content/regions/%s.json" % id)
		for name in region["scenarios"]:
			var gs = load("res://autoload/game_state.gd").new()
			add_child_autofree(gs)
			var flow := RegionFlow.new(maps, gs)
			var scenario: Dictionary = region["scenarios"][name]
			assert_true(flow.begin(scenario["start"]))
			for step in scenario["steps"]:
				var ok := flow.step(step)
				assert_true(ok, "%s/%s #%d: %s" % [id, name, flow.trace.size(), flow.errors])
				if not ok:
					break

func test_unavailable_choice_cannot_skip_npc_conditions():
	var gs = load("res://autoload/game_state.gd").new()
	add_child_autofree(gs)
	var flow := RegionFlow.new(MapLint.load_maps(), gs)
	assert_false(flow.dialogue(DialogueCatalog.load_dialogue("qg_dorn"), ["ruin_report", null]))
	assert_eq(gs.gold, 0)
	assert_true(gs.is_quest_inactive("oak_stone_echo"))

func test_missing_interaction_fails_even_if_cell_is_reachable():
	var gs = load("res://autoload/game_state.gd").new()
	add_child_autofree(gs)
	var flow := RegionFlow.new(MapLint.load_maps(), gs)
	flow.begin({"map": "wild_sw", "entry": "start"})
	assert_false(flow.step({"op": "chest", "map": "wild_sw", "pos": [7, 8]}))
