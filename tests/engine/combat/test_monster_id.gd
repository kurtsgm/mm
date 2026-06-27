extends GutTest

func test_from_def_copies_monster_id():
	var def := MonsterDef.new()
	def.id = "goblin"
	def.hp_max = 5
	var m := Monster.from_def(def)
	assert_eq(m.monster_id, "goblin")

func test_goblin_tres_has_id():
	var def: MonsterDef = load("res://content/monsters/goblin.tres")
	assert_eq(def.id, "goblin")

func test_ogre_tres_has_id():
	var def: MonsterDef = load("res://content/monsters/ogre.tres")
	assert_eq(def.id, "ogre")

func test_dream_wisp_tres_has_id():
	var def: MonsterDef = load("res://content/monsters/dream_wisp.tres")
	assert_eq(def.id, "dream_wisp")
