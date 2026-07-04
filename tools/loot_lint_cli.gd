extends SceneTree
# 掉落內容一致性檢查的 CLI 包裝：跑 LootLint.check(LootPool.equipment_bases()) 並印報告。
# 執行：godot --headless --path . --script res://tools/loot_lint_cli.gd
# 退出碼：有任何問題 → 1，否則 0。

func _initialize() -> void:
	var issues := LootLint.check(LootPool.equipment_bases())
	print("=== loot_lint 掉落內容一致性檢查 ===")
	if issues.is_empty():
		print("[loot_lint] OK：掉落內容一致")
		quit(0)
	else:
		for s in issues:
			printerr("[loot_lint] ", s)
		print("--- 合計：%d 個問題 ---" % issues.size())
		quit(1)
