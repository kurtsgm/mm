extends GutTest

func _char_with_status() -> Character:
	var c := Character.new()
	c.name = "英雄"; c.hp_max = 20; c.hp = 20
	c.statuses.append(StatusCatalog.poison(3, 4))
	c.statuses.append(StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, 2, 2))
	return c

func _party_data() -> SaveData:
	var d := SaveData.new()
	var p := Party.new()
	var members: Array[Character] = [_char_with_status()]
	p.members = members
	d.party = p
	d.inventory = Inventory.new()
	return d

func test_statuses_round_trip():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_party_data()))
	var st = back.party.members[0].statuses
	assert_eq(st.size(), 2)
	assert_eq(st[0].kind, StatusEffect.Kind.POISON)
	assert_eq(st[0].potency, 3)
	assert_eq(st[0].remaining, 4)
	assert_eq(st[1].kind, StatusEffect.Kind.STAT_MOD)
	assert_eq(st[1].amount, 2)

func test_statuses_absent_is_empty():
	var raw := SaveSerializer.to_dict(_party_data())
	raw["state"]["party"][0].erase("statuses")
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.party.members[0].statuses.size(), 0)

func test_version_is_10():
	assert_eq(SaveSerializer.VERSION, 10)
	assert_eq(SaveSerializer.to_dict(_party_data())["version"], 10)
