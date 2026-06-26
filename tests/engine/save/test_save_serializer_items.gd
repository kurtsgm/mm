extends GutTest

# 假 resolver：把 id 對應到測試自建的 ItemDef（不依賴 content/ 或 ItemCatalog）。
func _resolver(id: String) -> ItemDef:
	var d := ItemDef.new()
	d.id = id
	if id == "sword":
		d.category = ItemDef.Category.WEAPON; d.attack = 6
	elif id == "leather":
		d.category = ItemDef.Category.ARMOR; d.armor = 3
	else:
		d.category = ItemDef.Category.CONSUMABLE; d.heal_hp = 10
	return d

func _sample_with_items() -> SaveData:
	var c := Character.new()
	c.name = "Gerard"; c.might = 15
	c.equipment.equip(_resolver("sword"))
	c.equipment.equip(_resolver("leather"))
	var p := Party.new()
	p.members = [c]
	var inv := Inventory.new()
	inv.add("potion", 2)
	inv.add("ether", 1)
	var d := SaveData.new()
	d.party = p
	d.inventory = inv
	return d

func test_inventory_roundtrips_without_resolver():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_sample_with_items()))
	assert_not_null(back.inventory)
	assert_eq(back.inventory.count_of("potion"), 2)
	assert_eq(back.inventory.count_of("ether"), 1)

func test_equipment_roundtrips_with_resolver():
	var raw := SaveSerializer.to_dict(_sample_with_items())
	var back := SaveSerializer.from_dict(raw, Callable(self, "_resolver"))
	var c: Character = back.party.members[0]
	assert_eq(c.equipment.total_attack(), 6, "武器經 resolver 還原")
	assert_eq(c.equipment.total_armor(), 3, "防具經 resolver 還原")
	assert_eq(c.attack_power(), 21)   # might 15 + 武器 6

func test_equipment_dropped_without_resolver():
	var raw := SaveSerializer.to_dict(_sample_with_items())
	var back := SaveSerializer.from_dict(raw)   # 無 resolver
	var c: Character = back.party.members[0]
	assert_eq(c.equipment.total_attack(), 0, "無 resolver → 裝備留空（序列化器保持純可測）")

func test_missing_items_fields_load_empty():
	# 模擬 M5a（version 1）舊檔：無 inventory / equipment 欄
	var raw := {
		"version": SaveSerializer.VERSION,
		"state": {
			"gold": 50, "map_id": "level01",
			"player_pos": [2, 3], "player_facing": 1,
			"party": [{"name": "Old", "level": 2, "hp": 10, "hp_max": 10}],
			"cleared_encounters": {},
		},
	}
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back, "version 1 舊檔應可讀（向後相容）")
	assert_eq(back.gold, 50)
	assert_true(back.inventory.is_empty())
	assert_eq(back.party.members[0].equipment.total_attack(), 0)

func test_rejects_malformed_player_pos():
	var raw := SaveSerializer.to_dict(_sample_with_items())
	raw["state"]["player_pos"] = []
	assert_null(SaveSerializer.from_dict(raw), "畸形座標 [] → 拒絕")
	raw["state"]["player_pos"] = [5]
	assert_null(SaveSerializer.from_dict(raw), "畸形座標 [5] → 拒絕")
