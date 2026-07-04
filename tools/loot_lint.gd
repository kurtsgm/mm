class_name LootLint
extends Object

# 掉落內容一致性檢查（純函式）。回問題字串清單，空＝通過。
static func check(bases: Array) -> Array:
	var issues: Array = []
	# 1) 每 10 級帶 (1-10,11-20,...,91-100) 至少一個 droppable base 覆蓋
	for band in range(10):
		var lo := band * 10 + 1
		var hi := lo + 9
		var covered := false
		for d in bases:
			if d.drop_weight > 0 and d.min_level <= hi and d.max_level >= lo:
				covered = true
				break
		if not covered:
			issues.append("等級帶 %d-%d 無 base 覆蓋" % [lo, hi])
	# 2) unique base_id 必須存在於 bases
	var ids: Dictionary = {}
	for d in bases:
		ids[d.id] = true
	for uid in UniqueCatalog.eligible(100):
		var bid: String = String(UniqueCatalog.entry(uid)["base_id"])
		if not ids.has(bid):
			issues.append("unique %s 的 base_id %s 不在 base 池" % [uid, bid])
	# 3) 七大遺器一致性
	var forbidden := ["命脈", "全世界的電源", "全世界電源", "第二核心", "第二具核心", "養活全世界", "養活整個世界"]
	var art := UniqueCatalog.artifacts()
	if art.size() != ArtifactSet.SET_SIZE:
		issues.append("神器數量應為 %d，實為 %d" % [ArtifactSet.SET_SIZE, art.size()])
	var seen_names: Dictionary = {}
	var elig := UniqueCatalog.eligible(100)
	for aid in art:
		var e := UniqueCatalog.entry(aid)
		var nm := String(e.get("name", ""))
		if seen_names.has(nm):
			issues.append("神器名稱重複：%s" % nm)
		seen_names[nm] = true
		if not ids.has(String(e.get("base_id", ""))):
			issues.append("神器 %s 的 base_id %s 不在 base 池" % [aid, String(e.get("base_id", ""))])
		if String(e.get("set_id", "")) != ArtifactSet.SET_ID:
			issues.append("神器 %s 的 set_id 不是 %s" % [aid, ArtifactSet.SET_ID])
		if elig.has(aid):
			issues.append("神器 %s 不該出現在 eligible() 隨機池" % aid)
		for w in forbidden:
			if nm.find(w) != -1:
				issues.append("神器 %s 名稱含禁用階序字：%s" % [aid, w])
	return issues
