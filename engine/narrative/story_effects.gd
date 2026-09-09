class_name StoryEffects
extends Object

## Validate the entire effect batch against projected costs before changing live state.
## Dialogue choices and cutscene steps use this same command boundary.
static func apply(effects, ctx) -> ActionResult:
	if effects == null:
		return ActionResult.success()
	if not effects is Array:
		return ActionResult.failure(&"invalid_effect")
	var gold: int = ctx.gold
	var counts := {}
	for effect in effects:
		if not effect is Dictionary:
			return ActionResult.failure(&"invalid_effect")
		match String(effect.get("op", "")):
			"gold":
				gold += int(effect.get("value", 0))
				if gold < 0:
					return ActionResult.failure(&"no_gold", ["金幣不足。"])
			"give", "take":
				var id := String(effect.get("item", ""))
				if not ItemCatalog.has_item(id):
					return ActionResult.failure(&"invalid_item")
				var count := int(counts.get(id, ctx.inventory.count_of(id)))
				count += 1 if effect["op"] == "give" else -1
				if count < 0:
					return ActionResult.failure(&"not_owned", ["缺少需要的道具。"])
				counts[id] = count
			"set_flag", "clear_flag":
				if String(effect.get("flag", "")) == "":
					return ActionResult.failure(&"invalid_flag")
			"accept_quest", "advance_quest":
				var id := String(effect.get("quest", ""))
				var def = ctx._quest_def(id) if ctx.has_method("_quest_def") else QuestCatalog.load_quest(id)
				if def == null:
					return ActionResult.failure(&"invalid_quest")
			_:
				return ActionResult.failure(&"unsupported_effect")
	var events: Array = []
	# Commit resources/flags first. Quest notifications see the whole committed batch.
	for effect in effects:
		match String(effect["op"]):
			"gold":
				ctx.gold += int(effect.get("value", 0))
				events.append("金幣 %+d。" % int(effect.get("value", 0)))
			"give":
				ctx.inventory.add(String(effect["item"]), 1)
				events.append("獲得 %s。" % effect["item"])
			"take":
				ctx.inventory.remove(String(effect["item"]), 1)
				events.append("失去 %s。" % effect["item"])
			"set_flag":
				ctx.flags[String(effect["flag"])] = true
			"clear_flag":
				ctx.flags.erase(String(effect["flag"]))
	for effect in effects:
		match String(effect["op"]):
			"accept_quest": ctx.accept_quest(String(effect["quest"]))
			"advance_quest": ctx.advance_quest(String(effect["quest"]))
	if ctx.has_method("refresh_collect"):
		ctx.refresh_collect()
	return ActionResult.success(events)
