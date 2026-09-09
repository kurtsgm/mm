extends GutTest

class Ctx:
	var gold: int = 0
	var inventory := Inventory.new()

func _item(id: String, value: int) -> ItemDef:
	var d := ItemDef.new()
	d.id = id
	d.display_name = id
	d.value = value
	return d

func _spell(id: String, school: int, cost: int) -> SpellDef:
	var s := SpellDef.new()
	s.id = id
	s.display_name = id
	s.school = school
	s.gold_cost = cost
	return s

func _char(cls: String) -> Character:
	var c := Character.new()
	c.name = "T"
	c.char_class = cls
	c.hp = 0
	c.hp_max = 20
	c.sp = 0
	c.sp_max = 10
	c.condition = Character.Condition.UNCONSCIOUS
	return c

func test_buy_goods_success():
	var ctx := Ctx.new()
	ctx.gold = 100
	var res := VendorTransaction.buy_goods(ctx, _item("potion", 30))
	assert_true(res["ok"])
	assert_eq(ctx.gold, 70)
	assert_eq(ctx.inventory.count_of("potion"), 1)

func test_buy_goods_no_gold():
	var ctx := Ctx.new()
	ctx.gold = 10
	var res := VendorTransaction.buy_goods(ctx, _item("potion", 30))
	assert_false(res["ok"])
	assert_eq(res["reason"], "no_gold")
	assert_eq(ctx.gold, 10)
	assert_eq(ctx.inventory.count_of("potion"), 0)

func test_sell_goods_floor_price():
	var ctx := Ctx.new()
	ctx.inventory.add("short_sword", 1)
	var res := VendorTransaction.sell_goods(ctx, _item("short_sword", 25), 0.5)
	assert_true(res["ok"])
	assert_eq(ctx.gold, 12)                 # floor(25*0.5)=12
	assert_eq(ctx.inventory.count_of("short_sword"), 0)

func test_sell_goods_not_owned():
	var ctx := Ctx.new()
	var res := VendorTransaction.sell_goods(ctx, _item("short_sword", 25), 0.5)
	assert_false(res["ok"])
	assert_eq(res["reason"], "not_owned")

func test_learn_spell_success_appends():
	var ctx := Ctx.new()
	ctx.gold = 100
	var c := _char("Sorcerer")
	var res := VendorTransaction.learn_spell(ctx, _spell("spark", SpellDef.School.ARCANE, 80), c)
	assert_true(res["ok"])
	assert_eq(ctx.gold, 20)
	assert_true(c.known_spells.has("spark"))

func test_learn_spell_wrong_school():
	var ctx := Ctx.new()
	ctx.gold = 100
	var res := VendorTransaction.learn_spell(ctx, _spell("spark", SpellDef.School.ARCANE, 80), _char("Knight"))
	assert_false(res["ok"])
	assert_eq(res["reason"], "wrong_school")
	assert_eq(ctx.gold, 100)

func test_learn_spell_no_gold():
	var ctx := Ctx.new()
	ctx.gold = 10
	var res := VendorTransaction.learn_spell(ctx, _spell("spark", SpellDef.School.ARCANE, 80), _char("Sorcerer"))
	assert_eq(res["reason"], "no_gold")

func test_buy_service_revive():
	var ctx := Ctx.new()
	ctx.gold = 200
	var c := _char("Knight")                # UNCONSCIOUS
	c.condition = Character.Condition.DEAD
	var offer := {"name": "復活", "cost": 100, "effect": "revive", "target": "character"}
	var res := VendorTransaction.buy_service(ctx, offer, [c])
	assert_true(res["ok"])
	assert_eq(ctx.gold, 100)
	assert_eq(c.condition, Character.Condition.OK)
	assert_eq(c.hp, 1)

func test_buy_service_revive_invalid_on_healthy():
	var ctx := Ctx.new()
	ctx.gold = 200
	var c := _char("Knight")
	c.condition = Character.Condition.OK
	var offer := {"name": "復活", "cost": 100, "effect": "revive", "target": "character"}
	var res := VendorTransaction.buy_service(ctx, offer, [c])
	assert_false(res["ok"])
	assert_eq(res["reason"], "invalid_target")
	assert_eq(ctx.gold, 200)

func test_buy_service_rest_party():
	var ctx := Ctx.new()
	ctx.gold = 50
	var a := _char("Knight")                # UNCONSCIOUS, hp0 sp0
	var b := _char("Cleric")
	b.condition = Character.Condition.OK
	b.hp = 5
	b.sp = 2
	var offer := {"name": "住宿", "cost": 20, "effect": "rest", "target": "party"}
	var res := VendorTransaction.buy_service(ctx, offer, [a, b])
	assert_true(res["ok"])
	assert_eq(ctx.gold, 30)
	assert_eq(a.hp, 20)
	assert_eq(a.condition, Character.Condition.OK)   # 喚醒昏迷
	assert_eq(b.sp, 10)

func test_buy_service_no_gold():
	var ctx := Ctx.new()
	ctx.gold = 5
	var offer := {"name": "住宿", "cost": 20, "effect": "rest", "target": "party"}
	var res := VendorTransaction.buy_service(ctx, offer, [_char("Knight")])
	assert_eq(res["reason"], "no_gold")

func test_buy_service_rest_clears_ailments():
	var ctx := Ctx.new()
	ctx.gold = 50
	var c := _char("Knight")
	c.condition = Character.Condition.OK
	c.hp = 5
	c.statuses.append(StatusCatalog.poison(3, 4))   # 帶毒
	var offer := {"name": "住宿", "cost": 20, "effect": "rest", "target": "party"}
	var res := VendorTransaction.buy_service(ctx, offer, [c])
	assert_true(res["ok"])
	assert_eq(c.statuses.size(), 0)                 # 休息後狀態異常清空

func test_buy_service_heal_full_clears_ailments_at_full_hp():
	var ctx := Ctx.new()
	ctx.gold = 50
	var c := _char("Knight")
	c.condition = Character.Condition.OK             # 清醒
	c.hp = c.hp_max                                  # 已滿血
	c.statuses.append(StatusCatalog.poison(3, 4))    # 帶毒
	var offer := {"name": "神殿全補", "cost": 30, "effect": "heal_full", "target": "character"}
	var res := VendorTransaction.buy_service(ctx, offer, [c])
	assert_true(res["ok"])                           # 滿血仍應成功（清異常）
	assert_eq(c.statuses.size(), 0)                  # 狀態異常清空
	assert_false(res["events"].is_empty())           # 帶回非空事件

# --- 裝備買賣（ItemInstance 分支）---

func test_buy_base_equipment_adds_common_instance():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id; d.category = ItemDef.Category.WEAPON; d.attack = 6; d.value = 30; return d
	var inv := Inventory.new()
	var it := VendorTransaction.make_base_instance("iron_sword")
	inv.add_instance(it)
	assert_eq(it.quality, Quality.Q.COMMON)
	assert_eq(inv.instances().size(), 1)
	ItemInstance.base_resolver = Callable()

func test_sell_instance_gives_quality_scaled_gold():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id; d.category = ItemDef.Category.WEAPON; d.value = 30; return d
	var it := ItemInstance.new(); it.base_id = "iron_sword"; it.quality = Quality.Q.RARE
	assert_eq(it.sell_value(), 105)   # 30 * 3.5
	ItemInstance.base_resolver = Callable()

func test_buy_equipment_deducts_gold_and_adds_instance():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id; d.display_name = id; d.category = ItemDef.Category.WEAPON; d.value = 30; return d
	var ctx := Ctx.new()
	ctx.gold = 100
	var res := VendorTransaction.buy_equipment(ctx, "iron_sword")
	assert_true(res["ok"])
	assert_eq(ctx.gold, 70)                          # 100 - 30
	assert_eq(ctx.inventory.instances().size(), 1)
	var inst: ItemInstance = ctx.inventory.instances()[0]
	assert_eq(inst.base_id, "iron_sword")
	assert_eq(inst.quality, Quality.Q.COMMON)
	ItemInstance.base_resolver = Callable()

func test_buy_equipment_no_gold():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id; d.display_name = id; d.value = 30; return d
	var ctx := Ctx.new()
	ctx.gold = 10
	var res := VendorTransaction.buy_equipment(ctx, "iron_sword")
	assert_false(res["ok"])
	assert_eq(res["reason"], "no_gold")
	assert_eq(ctx.gold, 10)
	assert_eq(ctx.inventory.instances().size(), 0)
	ItemInstance.base_resolver = Callable()

func test_sell_equipment_adds_gold_and_removes_instance():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id; d.display_name = id; d.category = ItemDef.Category.WEAPON; d.value = 30; return d
	var ctx := Ctx.new()
	ctx.gold = 0
	var inst := ItemInstance.new(); inst.base_id = "iron_sword"; inst.quality = Quality.Q.RARE
	ctx.inventory.add_instance(inst)
	var res := VendorTransaction.sell_equipment(ctx, inst)
	assert_true(res["ok"])
	assert_eq(ctx.gold, 105)                         # 30 * 3.5
	assert_eq(ctx.inventory.instances().size(), 0)
	ItemInstance.base_resolver = Callable()

func test_sell_equipment_not_owned():
	var ctx := Ctx.new()
	var inst := ItemInstance.new(); inst.base_id = "iron_sword"
	var res := VendorTransaction.sell_equipment(ctx, inst)
	assert_false(res["ok"])
	assert_eq(res["reason"], "not_owned")
	assert_eq(ctx.gold, 0)
	ItemInstance.base_resolver = Callable()

func test_invalid_equipment_and_negative_service_cost_leave_state_unchanged():
	ItemCatalog.install_resolver()
	var ctx := Ctx.new()
	ctx.gold = 50
	assert_false(VendorTransaction.buy_equipment(ctx, "missing").ok)
	assert_eq(ctx.inventory.instances().size(), 0)
	var character := _char("Cleric")
	assert_false(VendorTransaction.buy_service(ctx, {"cost": -5, "effect": "revive"}, [character]).ok)
	assert_eq(character.condition, Character.Condition.UNCONSCIOUS)
	assert_eq(ctx.gold, 50)
