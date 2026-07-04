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
	return issues
