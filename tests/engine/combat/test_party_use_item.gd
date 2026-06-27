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
	var ev := cs.party_use_item(_potion(), 1)   # 對隊伍 index 1 = Hurt
	assert_eq(hurt.hp, 30, "10 + 20 夾在上限")
	assert_gt(ev.size(), 0)
	assert_false(cs.current_combatant() == fast, "已前進，不再是 Fast 的回合")

func test_use_item_no_effect_does_not_advance():
	var full := _char("Full", 30, 30, 50)
	var cs := CombatSystem.new(_party([full]), _monsters([_monster("M", 100, 1)]), _rng(3))
	var ev := cs.party_use_item(_potion(), 0)   # 滿血 → can_use=false
	assert_eq(ev.size(), 0, "無效：回空")
	assert_true(cs.is_party_turn(), "未消耗回合")

func test_use_item_does_not_touch_inventory():
	# CombatSystem 不該引用 GameState/Inventory；此測試僅確認方法簽章與回傳，背包由 layer 處理。
	var hurt := _char("Hurt", 5, 30, 50)
	var cs := CombatSystem.new(_party([hurt]), _monsters([_monster("M", 100, 1)]), _rng(3))
	var ev := cs.party_use_item(_potion(), 0)
	assert_gt(ev.size(), 0)
