extends GutTest

class FakeCombatant:
	var speed: int
	var tag: String
	func _init(s: int, t: String):
		speed = s
		tag = t

func _tags(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		out.append(c.tag)
	return out

func test_sorts_by_speed_desc():
	var a := FakeCombatant.new(5, "a")
	var b := FakeCombatant.new(10, "b")
	var c := FakeCombatant.new(7, "c")
	assert_eq(_tags(TurnOrder.build([a, b, c])), ["b", "c", "a"])

func test_tie_break_is_stable_input_order():
	var a := FakeCombatant.new(8, "a")
	var b := FakeCombatant.new(8, "b")
	var c := FakeCombatant.new(8, "c")
	assert_eq(_tags(TurnOrder.build([c, a, b])), ["c", "a", "b"])
