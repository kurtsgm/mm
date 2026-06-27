extends GutTest

func _antidote() -> ItemDef:
	var it := ItemDef.new()
	it.id = "antidote"; it.display_name = "解毒劑"
	it.category = ItemDef.Category.CONSUMABLE
	it.cure_kinds = [StatusEffect.Kind.POISON]
	return it

func _char_poisoned() -> Character:
	var c := Character.new()
	c.name = "英雄"; c.hp = 20; c.hp_max = 20; c.condition = Character.Condition.OK
	c.statuses.append(StatusCatalog.poison(3, 4))
	return c

func test_antidote_usable_only_when_curable_status_present():
	assert_true(ItemEffects.can_use(_antidote(), _char_poisoned()))
	var clean := Character.new()
	clean.hp = 20; clean.hp_max = 20; clean.condition = Character.Condition.OK
	assert_false(ItemEffects.can_use(_antidote(), clean))

func test_antidote_removes_poison():
	var c := _char_poisoned()
	var events := ItemEffects.apply(_antidote(), c)
	assert_false(events.is_empty())
	for s in c.statuses:
		assert_ne(s.kind, StatusEffect.Kind.POISON)

func test_antidote_keeps_non_cured_kinds():
	var c := _char_poisoned()
	c.statuses.append(StatusCatalog.sleep(2))
	ItemEffects.apply(_antidote(), c)
	var has_sleep := false
	for s in c.statuses:
		if s.kind == StatusEffect.Kind.SLEEP: has_sleep = true
	assert_true(has_sleep)
