extends GutTest

# 裝備位測試需真 base 解析器：eternal_lamp 的 base_id=amulet_of_power(category=ACCESSORY)，
# can_equip/base_def().category 才成立。裝到角色欄後由 equipped() 進 owned_ids。
func before_all():
	ItemCatalog.install_resolver()

func after_all():
	ItemInstance.base_resolver = Callable()

func _inv_with(ids: Array) -> Inventory:
	var inv := Inventory.new()
	for id in ids:
		inv.add_instance(UniqueCatalog.make(id))
	return inv

func test_owned_count_dedup_and_filter():
	var inv := _inv_with(["eternal_lamp", "eternal_lamp", "choir_crown"])
	inv.add_instance(UniqueCatalog.make("dawnblade"))   # 一般 unique 不計
	assert_eq(ArtifactSet.owned_count(inv, null), 2)

func test_incomplete_and_complete():
	var six := ["eternal_lamp", "genesis_casket", "stasis_reliquary",
		"wayfinder_astrolabe", "starender_blade", "choir_crown"]
	assert_false(ArtifactSet.is_complete(_inv_with(six), null))
	assert_true(ArtifactSet.is_complete(_inv_with(six + ["aegis_field_core"]), null))

func test_set_bonus_shape():
	var b := ArtifactSet.set_bonus()
	assert_true(b.size() >= 1)

# 裝備位路徑：神器裝在隊員身上、背包空 → 也要計入（核心需求）。
func test_owned_count_counts_equipped_artifact():
	var c := Character.new()
	var lamp := UniqueCatalog.make("eternal_lamp")
	assert_true(c.equipment.can_equip(lamp))
	c.equipment.equip(lamp)
	var party := Party.new()
	party.members.append(c)
	var inv := Inventory.new()   # 空背包
	assert_eq(ArtifactSet.owned_count(inv, party), 1)
	assert_false(ArtifactSet.is_complete(inv, party))   # 1/7 未集齊

# 跨來源去重：同一神器同時「裝備位 + 背包」→ 依 unique_id 去重、只算 1（不重複計）。
func test_owned_count_dedups_equipped_and_backpack():
	var c := Character.new()
	c.equipment.equip(UniqueCatalog.make("eternal_lamp"))
	var party := Party.new()
	party.members.append(c)
	var inv := _inv_with(["eternal_lamp"])   # 背包同一個 id
	assert_eq(ArtifactSet.owned_count(inv, party), 1)
