class_name GameFlow
extends RefCounted

## Ephemeral session flow. Only the current owner can finish or hand off control.
## Presentation observes changed; gameplay rules and saves do not own input locks.
signal changed

enum Mode { EXPLORATION, MENU, ENGAGING, COMBAT, CHEST, DIALOGUE, CUTSCENE, VENDOR, TRAVEL, TRANSITION, GAME_OVER }

var mode: Mode = Mode.EXPLORATION
var owner: StringName = &""
var _menu_return: Mode = Mode.EXPLORATION

func can_explore() -> bool:
	return mode == Mode.EXPLORATION

func owns(candidate: StringName) -> bool:
	return candidate != &"" and owner == candidate

func enter(next: Mode, next_owner: StringName) -> bool:
	if not can_explore() or next_owner == &"" or next in [Mode.EXPLORATION, Mode.MENU, Mode.GAME_OVER]:
		return false
	_change_mode(next, next_owner)
	return true

func open_menu(next_owner: StringName) -> bool:
	if next_owner == &"" or not (can_explore() or (mode == Mode.GAME_OVER and next_owner == &"save")):
		return false
	_menu_return = mode
	_change_mode(Mode.MENU, next_owner)
	return true

func can_save() -> bool:
	return mode == Mode.MENU and owner == &"save" and _menu_return == Mode.EXPLORATION

func handoff(current_owner: StringName, next: Mode, next_owner: StringName) -> bool:
	if not owns(current_owner) or next_owner == &"":
		return false
	var allowed := (mode == Mode.ENGAGING and next == Mode.COMBAT) or (mode == Mode.COMBAT and next in [Mode.CHEST, Mode.GAME_OVER]) or (next == Mode.TRANSITION and (mode == Mode.TRAVEL or (mode == Mode.MENU and _menu_return == Mode.EXPLORATION)))
	if not allowed:
		return false
	_change_mode(next, next_owner)
	return true

func finish(current_owner: StringName) -> bool:
	if not owns(current_owner) or mode == Mode.GAME_OVER:
		return false
	var next := _menu_return if mode == Mode.MENU else Mode.EXPLORATION
	_change_mode(next, &"game_over" if next == Mode.GAME_OVER else &"")
	return true

## Loading restores the world while the save menu still owns input until it closes.
func world_loaded() -> void:
	if mode == Mode.MENU and owner == &"save":
		_menu_return = Mode.EXPLORATION
		changed.emit()
	elif mode == Mode.GAME_OVER:
		_change_mode(Mode.EXPLORATION, &"")

func _change_mode(next: Mode, next_owner: StringName) -> void:
	mode = next
	owner = next_owner
	changed.emit()
