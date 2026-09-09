class_name DialogueRunner
extends RefCounted
# 對話流程狀態機：持有對話圖與注入 context，篩選可選 choices、套用選擇的 effects、依 goto 推進。

var _data: DialogueData
var _ctx
var _current: String
var _finished: bool = false

func _init(data: DialogueData, ctx) -> void:
	_data = data
	_ctx = ctx
	_current = data.start

func current_node() -> Dictionary:
	return _data.node(_current)

func is_finished() -> bool:
	return _finished

func available_choices() -> Array:
	var out: Array = []
	for c in current_node().get("choices", []):
		if DialogueCondition.passes(c.get("require", null), _ctx):
			out.append(c)
	return out

func choose(choice: Dictionary) -> ActionResult:
	if _finished or not available_choices().has(choice):
		return ActionResult.failure(&"stale_choice", ["這個選項目前已無法選擇。"])
	var result := StoryEffects.apply(choice.get("effects", []), _ctx)
	if not result.ok:
		return result
	var goto = choice.get("goto", null)
	if goto == null:
		_finished = true
	else:
		_current = String(goto)
	return result
