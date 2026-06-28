extends SceneTree
# 升級節奏模擬器 CLI：跑 ProgressionSim → 輸出 docs/balance/progression.md。
# 執行：godot --headless --path . --script res://tools/progression_cli.gd
# 可選參數（放在 -- 之後）：--target 10 --seed 12345 --trials 12 --threshold 70 --out docs/balance/progression

func _initialize() -> void:
	var a := _parse_args()
	print("=== 升級節奏模擬器（target=L%d, seed=%d, trials=%d, threshold=%d%%）===" % [a["target"], a["seed"], a["trials"], a["threshold"]])
	var report := ProgressionSim.run(a["target"], a["seed"], a["trials"], a["threshold"] / 100.0)
	var meta := {"seed": a["seed"], "trials": a["trials"]}
	var md := ProgressionReport.to_markdown(report, meta)
	_write("res://%s.md" % a["out"], md)
	print(md)
	print("→ 寫出 %s.md" % a["out"])
	quit(0)

func _parse_args() -> Dictionary:
	var d := {"target": 100, "seed": 12345, "trials": 12, "threshold": 70, "out": "docs/balance/progression"}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size() - 1:
		match args[i]:
			"--target": d["target"] = int(args[i + 1])
			"--seed": d["seed"] = int(args[i + 1])
			"--trials": d["trials"] = int(args[i + 1])
			"--threshold": d["threshold"] = int(args[i + 1])
			"--out": d["out"] = args[i + 1]
		i += 2
	return d

func _write(path: String, text: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(path).get_base_dir()
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("無法寫入 %s" % path)
		return
	f.store_string(text)
	f.close()
