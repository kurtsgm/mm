extends SceneTree
# /check-quest 的 CLI 包裝：跑 QuestLint.run() 並印出報告。
# 執行：godot --headless --path . --script res://tools/quest_lint_cli.gd
# 退出碼：有 ERROR → 1，否則 0（warning 不影響退出碼）。

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
	quit(1 if not errors.is_empty() else 0)
