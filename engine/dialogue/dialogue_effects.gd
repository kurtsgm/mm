class_name DialogueEffects
extends Object
# 依序套用對話 choice 的 effects，回人可讀描述（給訊息列）。純函式、收注入 context。
# context 需 gold:int(可寫)、inventory(add/remove)、flags:Dictionary(可寫)。未知 op 跳過。

static func apply(effects, ctx) -> Array:
	var out: Array = []
	if effects == null or typeof(effects) != TYPE_ARRAY:
		return out
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		match String(e.get("op", "")):
			"gold":
				ctx.gold = maxi(ctx.gold + int(e.get("value", 0)), 0)
				out.append("金幣 %+d。" % int(e.get("value", 0)))
			"give":
				var gid := String(e.get("item", ""))
				if gid != "":
					ctx.inventory.add(gid, 1)
					out.append("獲得 %s。" % gid)
			"take":
				var tid := String(e.get("item", ""))
				if tid != "":
					ctx.inventory.remove(tid, 1)
					out.append("失去 %s。" % tid)
			"set_flag":
				ctx.flags[String(e.get("flag", ""))] = true
			"clear_flag":
				ctx.flags.erase(String(e.get("flag", "")))
			_:
				pass
	return out
