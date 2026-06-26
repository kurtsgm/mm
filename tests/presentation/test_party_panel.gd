extends GutTest

func _party_of(n: int) -> Party:
	var p := Party.new()
	var ms: Array[Character] = []
	for i in n:
		var c := Character.new()
		c.name = "C%d" % i
		c.char_class = "Knight"
		c.level = 1
		c.hp = 20
		c.hp_max = 20
		c.sp = 5
		c.sp_max = 5
		c.condition = Character.Condition.OK
		ms.append(c)
	p.members = ms
	return p

func _panel(party: Party) -> PartyPanel:
	var panel := PartyPanel.new()
	add_child_autofree(panel)
	panel.setup(party)
	return panel

func test_one_card_per_member():
	var panel := _panel(_party_of(3))
	assert_eq(panel.get_child_count(), 3)
	assert_true(panel.get_child(0) is PartyMemberCard)

func test_member_damage_flashes_only_its_card():
	var party := _party_of(2)
	var panel := _panel(party)
	party.members[1].take_damage(3)
	assert_true((panel.get_child(1) as PartyMemberCard).is_hit_active())
	assert_false((panel.get_child(0) as PartyMemberCard).is_hit_active())

func test_refresh_updates_card_labels():
	var party := _party_of(1)
	var panel := _panel(party)
	party.members[0].hp = 5
	party.members[0].hp_max = 20
	panel.refresh()
	assert_eq((panel.get_child(0) as PartyMemberCard)._hp_label.text, "HP 5/20")

func test_sync_keeps_cards_when_same_party():
	var party := _party_of(2)
	var panel := _panel(party)
	var card0 := panel.get_child(0)
	panel.sync(party)
	assert_eq(panel.get_child(0), card0)

func test_sync_rebuilds_when_party_replaced():
	var panel := _panel(_party_of(2))
	var party_b := _party_of(2)
	panel.sync(party_b)
	assert_eq(panel.get_child_count(), 2)
	assert_eq((panel.get_child(0) as PartyMemberCard).character(), party_b.members[0])
