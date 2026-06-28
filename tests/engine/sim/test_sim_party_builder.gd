extends GutTest

func _find(p: Party, name: String) -> Character:
	for m in p.members:
		if m.name == name:
			return m
	return null

func test_builds_six_at_target_level_all_conscious_full():
	var p := SimPartyBuilder.build(5)
	assert_eq(p.members.size(), 6)
	for m in p.members:
		assert_eq(m.level, 5)
		assert_eq(m.condition, Character.Condition.OK)
		assert_eq(m.hp, m.hp_max)
		assert_eq(m.sp, m.sp_max)

func test_stats_match_catalog():
	# Gerard Knight L5: hp_max = 30 + 4*6 = 54；endurance = 18 + 4 = 22
	var gerard := _find(SimPartyBuilder.build(5), "Gerard")
	assert_eq(gerard.hp_max, 54)
	assert_eq(gerard.endurance, 22)

func test_class_differentiation_in_built_party():
	var p := SimPartyBuilder.build(6)
	var knight := _find(p, "Gerard")
	var sorc := _find(p, "Cassia")
	assert_gt(knight.hp_max, sorc.hp_max)
	assert_gt(sorc.intellect, knight.intellect)

func test_assigns_class_spells_and_wakes_cleric():
	var p := SimPartyBuilder.build(3)
	assert_true(_find(p, "Cassia").known_spells.has("spark"))     # Sorcerer
	var marcus := _find(p, "Marcus")                               # Cleric（預設昏迷）
	assert_true(marcus.known_spells.has("heal"))
	assert_eq(marcus.condition, Character.Condition.OK)            # 模擬一律清醒
	assert_true(_find(p, "Cordelia").known_spells.has("heal"))    # Paladin

func test_alternative_catalog_override():
	# 傳替代 catalog（純假表，只需 stats_at_level(class, level)）→ build 採用之
	var p := SimPartyBuilder.build(3, FakeCatalog)
	for m in p.members:
		assert_eq(m.hp_max, 99)
		assert_eq(m.might, 1)

class FakeCatalog:
	static func stats_at_level(_c: String, _level: int) -> Dictionary:
		return {"might": 1, "intellect": 1, "personality": 1, "endurance": 1, "speed": 1, "accuracy": 1, "luck": 1, "hp_max": 99, "sp_max": 9}
