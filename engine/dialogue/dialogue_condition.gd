class_name DialogueCondition
extends Object
# 評估對話/場景的 require（前置條件）。純函式，收注入 context。
# require: null/空 → true；多鍵全部成立才 true；未知鍵 → false（保守，避免誤放行）。
# context 需暴露 gold:int、inventory（has(id)）、flags:Dictionary。

static func passes(require, ctx) -> bool:
	if require == null:
		return true
	if typeof(require) != TYPE_DICTIONARY or require.is_empty():
		return true
	for key in require:
		match key:
			"gold_gte":
				if ctx.gold < int(require[key]):
					return false
			"has_item":
				if not ctx.inventory.has(String(require[key])):
					return false
			"flag":
				var want := bool(require.get("is", true))
				if ctx.flags.has(String(require[key])) != want:
					return false
			"is":
				pass  # 與 "flag" 成對，於 flag 分支處理
			"quest_active":
				if not ctx.is_quest_active(String(require[key])):
					return false
			"quest_done":
				if not ctx.is_quest_done(String(require[key])):
					return false
			"quest_inactive":
				if not ctx.is_quest_inactive(String(require[key])):
					return false
			"quest_stage":
				var spec = require[key]
				if typeof(spec) != TYPE_DICTIONARY:
					return false
				if ctx.quest_stage(String(spec.get("id", ""))) != int(spec.get("eq", -999)):
					return false
			_:
				return false
	return true
