class_name ActionResult
extends RefCounted

## A command result, independent of UI text or whether an effect produced a message.
var ok: bool
var reason: StringName
var events: Array

func _init(success: bool, code: StringName = &"ok", descriptions: Array = []) -> void:
	ok = success
	reason = code
	events = descriptions

static func success(descriptions: Array = []) -> ActionResult:
	return ActionResult.new(true, &"ok", descriptions)

static func failure(code: StringName, descriptions: Array = []) -> ActionResult:
	return ActionResult.new(false, code, descriptions)
