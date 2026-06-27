extends GutTest

class FakeInv:
	var _s: Array = []
	func add(id: String, count: int) -> void: _s.append({"id": id, "count": count})
	func stacks() -> Array: return _s

func _char(hp: int, hp_max: int) -> Character:
	var c := Character.new()
	c.name = "C"; c.hp = hp; c.hp_max = hp_max; c.sp = 0; c.sp_max = 0
	c.condition = Character.Condition.OK
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for m in members: typed.append(m)
	p.members = typed
	return p

func _potion() -> ItemDef:
	var it := ItemDef.new()
	it.id = "potion"; it.display_name = "藥水"
	it.category = ItemDef.Category.CONSUMABLE; it.heal_hp = 10
	return it

func _sword() -> ItemDef:
	var it := ItemDef.new()
	it.id = "sword"; it.display_name = "劍"; it.category = ItemDef.Category.WEAPON
	return it

var _items := {}
func _resolve(id) -> ItemDef: return _items.get(id, null)

func before_each():
	_items = {"potion": _potion(), "sword": _sword()}

func test_lists_consumable_usable_on_some_ally():
	var inv := FakeInv.new(); inv.add("potion", 2); inv.add("sword", 1)
	var party := _party([_char(5, 30)])   # 受傷 → 藥水可用
	var out := CombatItems.usable(inv, party, Callable(self, "_resolve"))
	assert_eq(out.size(), 1)
	assert_eq(out[0].id, "potion", "只列可用消耗品，排除武器")

func test_excludes_when_no_ally_benefits():
	var inv := FakeInv.new(); inv.add("potion", 2)
	var party := _party([_char(30, 30)])  # 滿血 → 藥水無人可用
	assert_eq(CombatItems.usable(inv, party, Callable(self, "_resolve")), [])

func test_empty_inventory():
	assert_eq(CombatItems.usable(FakeInv.new(), _party([_char(5, 30)]), Callable(self, "_resolve")), [])
