extends GutTest

func before_all():
	ItemInstance.base_resolver = func(id):
		var d := ItemDef.new(); d.id = id; d.category = ItemDef.Category.WEAPON; d.attack = 6; return d

func after_all():
	ItemInstance.base_resolver = Callable()

func test_inventory_instances_roundtrip():
	var data := SaveData.new()
	data.party = Party.new(); data.party.members = []
	data.inventory = Inventory.new()
	data.inventory.add("potion", 2)
	var it := ItemInstance.new(); it.base_id = "iron_sword"; it.quality = Quality.Q.FINE
	it.affixes = [{"id": "sharp", "kind": 0, "mods": {ItemStat.S.ATTACK: 3}}]
	data.inventory.add_instance(it)
	var raw := SaveSerializer.to_dict(data)
	assert_eq(int(raw["version"]), 12)
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.inventory.count_of("potion"), 2)
	assert_eq(back.inventory.instances().size(), 1)
	assert_eq((back.inventory.instances()[0] as ItemInstance).total_attack(), 9)

func test_equipped_instance_roundtrip():
	var c := Character.new(); c.name = "H"; c.char_class = "knight"; c.level = 1
	var it := ItemInstance.new(); it.base_id = "iron_sword"; it.quality = Quality.Q.RARE
	c.equipment.equip(it)
	var data := SaveData.new(); data.party = Party.new(); data.party.members = [c]; data.inventory = Inventory.new()
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(data))
	var w = back.party.members[0].equipment.get_item(Equipment.Slot.WEAPON)
	assert_not_null(w)
	assert_eq(w.quality, Quality.Q.RARE)

# 神器（MYTHIC unique）存檔往返：unique_id/quality 存活，且 ArtifactSet 仍計入
# （capstone 觸發全靠 unique_id 序列化後仍在 → 鎖住此契約）。
func test_mythic_artifact_survives_roundtrip_and_stays_counted():
	var data := SaveData.new()
	data.party = Party.new(); data.party.members = []
	data.inventory = Inventory.new()
	data.inventory.add_instance(UniqueCatalog.make("eternal_lamp"))
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(data))
	assert_eq(back.inventory.instances().size(), 1)
	var reloaded := back.inventory.instances()[0] as ItemInstance
	assert_eq(reloaded.unique_id, "eternal_lamp")
	assert_eq(reloaded.quality, Quality.Q.MYTHIC)
	assert_eq(ArtifactSet.owned_count(back.inventory, null), 1)
