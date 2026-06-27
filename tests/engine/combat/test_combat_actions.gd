extends GutTest

func test_base_actions_always_present():
	var a := CombatActions.available(false, false)
	assert_eq(a, ["attack", "defend", "run"])

func test_spell_added_when_has_combat_spell():
	assert_true(CombatActions.available(true, false).has("spell"))

func test_item_added_when_has_usable_item():
	assert_true(CombatActions.available(false, true).has("item"))

func test_order_is_attack_defend_spell_item_run():
	assert_eq(CombatActions.available(true, true), ["attack", "defend", "spell", "item", "run"])
