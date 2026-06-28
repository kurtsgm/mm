class_name ProgressionReport
extends Object
# 把 ProgressionSim.run() 報告組成人看的 markdown。純字串組裝、無副作用。

static func to_markdown(report: Dictionary, meta: Dictionary) -> String:
	var out := "# XP 經濟／升級節奏模擬（Progression）\n\n"
	out += "- 基底亂數種子：%d\n" % int(meta.get("seed", 0))
	out += "- 每遭遇估算 trials：%d\n" % int(meta.get("trials", 0))
	out += "- 目標等級：L%d\n" % int(report.get("target_level", 0))
	out += "- 勝率門檻：%.0f%%\n" % (float(report.get("win_threshold", 0.0)) * 100.0)
	out += "- 假設：每場之間**完整休息**（全隊回滿、復活）——聚焦 XP 節奏而非連戰耗損。\n"
	out += "- 是否達標：%s（最終最低等級 L%d、平均 L%.1f、總場數 %d）\n\n" % [
		"達標" if bool(report.get("reached_target", false)) else "未達標（卡住）",
		int(report.get("final_min_level", 0)), float(report.get("final_avg_level", 0.0)),
		int((report.get("fights", []) as Array).size())]

	out += "## 每級場數（升一級要打幾場）\n\n"
	out += "| 隊伍等級 | 場數 |\n|---|---|\n"
	var fpl: Dictionary = report.get("fights_per_level", {})
	var keys := fpl.keys()
	keys.sort()
	for k in keys:
		out += "| %d | %d |\n" % [int(k), int(fpl[k])]
	out += "\n"

	out += "## 遭遇使用次數\n\n"
	var usage := {}
	for f in report.get("fights", []):
		var e := String(f["encounter"])
		usage[e] = int(usage.get(e, 0)) + 1
	out += "| 遭遇 | 次數 |\n|---|---|\n"
	for e in usage:
		out += "| `%s` | %d |\n" % [e, int(usage[e])]
	out += "\n"

	out += "## 場次時間軸\n\n"
	out += "| # | 遭遇 | 隊伍等級 | 總XP | 勝 | 平均等級 |\n|---|---|---|---|---|---|\n"
	for f in report.get("fights", []):
		out += "| %d | `%s` | %d | %d | %s | %.1f |\n" % [
			int(f["index"]), String(f["encounter"]), int(f["party_level"]),
			int(f["xp_total"]), "✓" if bool(f["victory"]) else "✗", float(f["avg_level"])]
	out += "\n"
	return out
