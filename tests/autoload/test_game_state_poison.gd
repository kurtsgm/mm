extends GutTest

func _gs() -> Node:
	var gs = load("res://autoload/game_state.gd").new()
	add_child_autofree(gs)
	gs.quest_resolver = Callable(self, "_resolve")
	var p := Party.new()
	var c := Character.new()
	c.name = "英雄"; c.hp = 20; c.hp_max = 20; c.condition = Character.Condition.OK
	c.statuses.append(StatusCatalog.poison(2, 9))
	var members: Array[Character] = [c]
	p.members = members
	gs.party = p
	return gs

func _resolve(_id) -> QuestDef:
	return null

func test_poison_ticks_every_n_steps():
	var gs = _gs()
	var hero = gs.party.members[0]
	for i in gs.STEP_PER_TICK - 1:
		gs.notify_enter("m", Vector2i(i, 0))
	assert_eq(hero.hp, 20)                 # 未達門檻不扣
	gs.notify_enter("m", Vector2i(9, 0))
	assert_eq(hero.hp, 18)                 # 第 5 步扣 2
