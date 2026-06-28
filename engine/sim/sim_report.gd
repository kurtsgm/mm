class_name SimReport
extends Object
# 把難度表 rows 組成人看的 markdown 與機器讀的 csv。純字串組裝、無副作用。

static func to_csv(rows: Array) -> String:
	var lines := ["encounter,level,win_rate,avg_rounds,avg_deaths,avg_hp_pct_on_win,timeouts,n"]
	for r in rows:
		lines.append("%s,%d,%.3f,%.2f,%.2f,%.3f,%d,%d" % [
			r["encounter"], r["level"], r["win_rate"], r["avg_rounds"],
			r["avg_deaths"], r["avg_hp_pct_on_win"], r["timeouts"], r["n"]])
	return "\n".join(lines) + "\n"

static func to_markdown(rows: Array, meta: Dictionary) -> String:
	var out := "# 戰鬥難度表（Combat Difficulty Matrix）\n\n"
	out += "- 每格場數 N：%d\n" % int(meta.get("n", 0))
	out += "- 基底亂數種子：%d\n" % int(meta.get("seed", 0))
	out += "- 成長模型：per-class（ClassCatalog）\n"
	out += "- policy：中等啟發式（復活 > 補血(<40%) > 期望傷害最高法術 > 集火最低血怪）\n\n"
	var by_enc := {}
	var order := []
	for r in rows:
		var e := String(r["encounter"])
		if not by_enc.has(e):
			by_enc[e] = []
			order.append(e)
		by_enc[e].append(r)
	for e in order:
		out += "## 遭遇 `%s`\n\n" % e
		out += "| 等級 | 勝率 | 平均回合 | 平均陣亡 | 勝場剩血% | timeout |\n"
		out += "|---|---|---|---|---|---|\n"
		for r in by_enc[e]:
			out += "| %d | %.0f%% | %.1f | %.2f | %.0f%% | %d |\n" % [
				int(r["level"]), float(r["win_rate"]) * 100.0, float(r["avg_rounds"]),
				float(r["avg_deaths"]), float(r["avg_hp_pct_on_win"]) * 100.0, int(r["timeouts"])]
		out += "\n"
	return out
