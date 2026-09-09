class_name WorldSnapshot
extends RefCounted

## Detached runtime state for rebuilding the visible world. MapData stays authored data.
## Queries return copies so simulations/render caches cannot mutate the source or each other.
var _opened: Dictionary
var _cleared: Dictionary
var _defeated: Dictionary
var _monsters: Dictionary

func _init(opened: Dictionary = {}, cleared: Dictionary = {}, defeated: Dictionary = {}, monsters: Dictionary = {}) -> void:
	_opened = opened.duplicate(true)
	_cleared = cleared.duplicate(true)
	_defeated = defeated.duplicate(true)
	_monsters = monsters.duplicate(true)

func opened_for(map_id: String) -> Dictionary:
	var result := {}
	for pos in _opened.get(map_id, []):
		result[pos] = true
	return result

func encounter_defeated(map_id: String, home: Vector2i, uid: String) -> bool:
	return _defeated.has(uid) or _cleared.get(map_id, []).has(home)

func monsters_for(map_id: String) -> Dictionary:
	return _monsters.get(map_id, {}).duplicate(true)
