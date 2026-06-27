extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

func _quest_ids() -> Array:
	var out: Array = []
	var da := DirAccess.open("res://content/quests")
	if da:
		for f in da.get_files():
			if f.ends_with(".json"):
				out.append(f.get_basename())
	return out

func test_all_quests_completable_end_to_end():
	for qid in _quest_ids():
		var def = QuestCatalog.load_quest(qid)
		assert_not_null(def, "quest %s 載入失敗" % qid)
		var gs = GameStateScript.new()
		add_child_autofree(gs)
		gs.quest_resolver = Callable(QuestCatalog, "load_quest")
		var r = QuestFlow.simulate(gs, def, qid)
		assert_true(r["completed"], "quest %s 無法端到端跑通" % qid)
