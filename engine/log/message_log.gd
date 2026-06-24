class_name MessageLog
extends RefCounted

signal changed

const MAX_LINES := 50

var _lines: Array[String] = []

func push(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	changed.emit()

func recent(n: int) -> Array[String]:
	if n <= 0:
		return []
	var start: int = maxi(0, _lines.size() - n)
	return _lines.slice(start)

func size() -> int:
	return _lines.size()
