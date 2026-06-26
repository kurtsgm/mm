class_name PartyPanel
extends HBoxContainer
# 左下隊伍列：每位 member 一張 PartyMemberCard，並把 member.damaged 接到該卡（受擊閃臉）。
# 讀檔會把 GameState.party 換成新實例 → sync() 偵測成員實例改變時整列重建。

var _cards: Array[PartyMemberCard] = []

func setup(party: Party) -> void:
	for c in _cards:
		remove_child(c)
		c.free()
	_cards.clear()
	add_theme_constant_override("separation", 8)
	for m in party.members:
		var card := PartyMemberCard.new()
		add_child(card)
		card.setup(m)
		_cards.append(card)
		m.damaged.connect(card._on_self_damaged)

func refresh() -> void:
	for card in _cards:
		card.refresh()

func sync(party: Party) -> void:
	if _same_members(party):
		refresh()
	else:
		setup(party)

func _same_members(party: Party) -> bool:
	if party.members.size() != _cards.size():
		return false
	for i in _cards.size():
		if _cards[i].character() != party.members[i]:
			return false
	return true
