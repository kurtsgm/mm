extends GutTest

func _char(n: String, hp: int, hp_max: int, speed: int) -> Character:
	var c := Character.new()
	c.name = n; c.hp = hp; c.hp_max = hp_max; c.sp = 0; c.sp_max = 0
	c.accuracy = 50; c.speed = speed; c.might = 1; c.condition = Character.Condition.OK
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for m in members: typed.append(m)
	p.members = typed
	return p

func _monster(n: String, hp: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = n; m.hp = hp; m.hp_max = hp; m.might = 1
	m.armor = 0; m.accuracy = 1; m.speed = speed; m.xp_reward = 1; m.gold_reward = 1
	return m

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr: out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s
	return r

func _potion() -> ItemDef:
	var it := ItemDef.new()
	it.id = "potion"; it.display_name = "治療藥水"
	it.category = ItemDef.Category.CONSUMABLE; it.heal_hp = 20
	return it

func test_use_heal_item_restores_target_and_advances():
	var fast := _char("Fast", 30, 30, 50)   # 快 → 先動
	var hurt := _char("Hurt", 10, 30, 5)
	var cs := CombatSystem.new(_party([fast, hurt]), _monsters([_monster("M", 100, 1)]), _rng(3))
	assert_true(cs.is_party_turn())
	var ev := cs.party_use_item(_potion(), 1, _inventory())   # 對隊伍 index 1 = Hurt
	assert_eq(hurt.hp, 30, "10 + 20 夾在上限")
	assert_gt(ev.events.size(), 0)
	assert_false(cs.current_combatant() == fast, "已前進，不再是 Fast 的回合")

func test_use_item_no_effect_does_not_advance():
	var full := _char("Full", 30, 30, 50)
	var cs := CombatSystem.new(_party([full]), _monsters([_monster("M", 100, 1)]), _rng(3))
	var ev := cs.party_use_item(_potion(), 0, _inventory())   # 滿血 → can_use=false
	assert_eq(ev.events.size(), 0, "無效：回空")
	assert_true(cs.is_party_turn(), "未消耗回合")

func test_use_item_consumes_injected_inventory_once():
	var hurt := _char("Hurt", 5, 30, 50)
	var cs := CombatSystem.new(_party([hurt]), _monsters([_monster("M", 100, 1)]), _rng(3))
	var inventory := _inventory()
	var ev := cs.party_use_item(_potion(), 0, inventory)
	assert_true(ev.ok)
	assert_eq(inventory.count_of("potion"), 0)

func _inventory() -> Inventory:
	var inventory := Inventory.new()
	inventory.add(_potion().id, 1)
	return inventory

func test_stale_inventory_cannot_heal_or_advance():
	var hurt := _char("Hurt", 5, 30, 50)
	var cs := CombatSystem.new(_party([hurt]), _monsters([_monster("M", 100, 1)]), _rng(3))
	var result := cs.party_use_item(_potion(), 0, Inventory.new())
	assert_false(result.ok)
	assert_eq(hurt.hp, 5)
	assert_eq(cs.current_combatant(), hurt)
