extends GutTest

func _find(p: Party, name: String) -> Character:
	for m in p.members:
		if m.name == name:
			return m
	return null

func test_restores_default_hpmax_at_default_level():
	# Gerard 預設 Knight L3 hp_max=28 → build(3) 應還原 28
	var gerard := _find(SimPartyBuilder.build(3), "Gerard")
	assert_eq(gerard.level, 3)
	assert_eq(gerard.hp_max, 28)

func test_grows_hpmax_per_level():
	# Gerard L3 hp_max=28 → 錨點 hp1=18；L4=33、L5=38
	assert_eq(_find(SimPartyBuilder.build(4), "Gerard").hp_max, 33)
	assert_eq(_find(SimPartyBuilder.build(5), "Gerard").hp_max, 38)

func test_all_members_conscious_and_full():
	var p := SimPartyBuilder.build(5)
	for m in p.members:
		assert_eq(m.condition, Character.Condition.OK)
		assert_eq(m.hp, m.hp_max)
		assert_eq(m.sp, m.sp_max)

func test_assigns_class_spells_and_wakes_cleric():
	var p := SimPartyBuilder.build(3)
	assert_true(_find(p, "Cassia").known_spells.has("spark"))     # Sorcerer
	var marcus := _find(p, "Marcus")                               # Cleric（預設昏迷）
	assert_true(marcus.known_spells.has("heal"))
	assert_eq(marcus.condition, Character.Condition.OK)            # 模擬一律清醒
	assert_true(_find(p, "Cordelia").known_spells.has("heal"))    # Paladin

func test_custom_growth_model():
	# 自訂每級 +10HP：Gerard 錨點 18（用預設 5 反推？不）→ 改用傳入值反推
	# 傳入 hp_per_level=10：hp1 = 28 - (3-1)*10 = 8；L5 = 8 + 4*10 = 48
	assert_eq(_find(SimPartyBuilder.build(5, 10, 2), "Gerard").hp_max, 48)
