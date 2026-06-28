extends SceneTree
# 戰鬥模擬器 CLI：跑「遭遇 × 等級」難度表，輸出 markdown + csv。
# 執行：godot --headless --path . --script res://tools/combat_sim_cli.gd
# 可選參數（放在 -- 之後）：--n 500 --lmin 2 --lmax 10 --seed 12345 --out docs/balance/combat-matrix

func _initialize() -> void:
	var a := _parse_args()
	var levels: Array = []
	for l in range(a["lmin"], a["lmax"] + 1):
		levels.append(l)
	print("=== 戰鬥模擬器：跑難度表（N=%d, L%d–%d, seed=%d）===" % [a["n"], a["lmin"], a["lmax"], a["seed"]])
	var rows := SimMatrix.run_all(levels, a["n"], a["seed"])
	var meta := {"n": a["n"], "seed": a["seed"]}
	var md := SimReport.to_markdown(rows, meta)
	var csv := SimReport.to_csv(rows)
	_write("res://%s.md" % a["out"], md)
	_write("res://%s.csv" % a["out"], csv)
	print(md)
	print("→ 寫出 %s.md 與 %s.csv" % [a["out"], a["out"]])
	quit(0)

func _parse_args() -> Dictionary:
	var d := {"n": 80, "lmin": 1, "lmax": 100, "seed": 12345, "out": "docs/balance/combat-matrix"}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size() - 1:
		match args[i]:
			"--n": d["n"] = int(args[i + 1])
			"--lmin": d["lmin"] = int(args[i + 1])
			"--lmax": d["lmax"] = int(args[i + 1])
			"--seed": d["seed"] = int(args[i + 1])
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
