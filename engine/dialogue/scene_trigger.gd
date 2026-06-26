class_name SceneTrigger
extends Object
# scene 是否該觸發的純判定：once 已觸發 → 否；require 不過 → 否；否則 → 是。

static func should_trigger(scene: Dictionary, ctx, already_triggered: bool) -> bool:
	if bool(scene.get("once", false)) and already_triggered:
		return false
	return DialogueCondition.passes(scene.get("require", null), ctx)
