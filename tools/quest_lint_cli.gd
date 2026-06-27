extends SceneTree
# /check-quest 的 CLI 包裝：跑 QuestLint.run() 並印出報告，再自動跑每個任務的 flow。
# 執行：godot --headless --path . --script res://tools/quest_lint_cli.gd
# 退出碼：有 ERROR 或 flow 跑不通 → 1，否則 0（warning 不影響退出碼）。

func _initialize() -> void:
	var r := QuestLint.run()
	var errors: Array = r["errors"]
	var warnings: Array = r["warnings"]
	print("=== /check-quest 任務內容驗證 ===")
	for w in warnings:
		print("WARN   ", w)
	for e in errors:
		print("ERROR  ", e)
	if errors.is_empty() and warnings.is_empty():
		print("✓ 無問題")
	print("--- 合計：%d error, %d warning ---" % [errors.size(), warnings.size()])
	var had_err := not errors.is_empty()

	print("--- 任務 flow 自動跑通 ---")
	var flow_fail := 0
	var da := DirAccess.open("res://content/quests")
	if da:
		for f in da.get_files():
			if not f.ends_with(".json"):
				continue
			var qid := f.get_basename()
			var def = QuestCatalog.load_quest(qid)
			if def == null:
				continue
			var gs = load("res://autoload/game_state.gd").new()
			root.add_child(gs)
			if gs.message_log == null:
				gs._ready()  # _initialize 期 add_child 不會觸發 _ready，手動初始化隊伍/背包/訊息列
			gs.quest_resolver = Callable(QuestCatalog, "load_quest")
			var ok: bool = QuestFlow.simulate(gs, def, qid)["completed"]
			print(("✓" if ok else "✗"), " flow ", qid)
			if not ok:
				flow_fail += 1
			gs.queue_free()
	if flow_fail > 0:
		print("ERROR  %d 個任務 flow 跑不通" % flow_fail)

	quit(1 if (had_err or flow_fail > 0) else 0)
