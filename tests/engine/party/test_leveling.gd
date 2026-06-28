extends GutTest

func test_xp_for_level_monotonic():
	for L in range(1, 100):
		assert_lt(Leveling.xp_for_level(L), Leveling.xp_for_level(L + 1), "xp_for_level 應單調遞增 (L=%d)" % L)

func test_grant_xp_no_levelup_below_threshold():
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	c.experience = 0
	var below: int = Leveling.xp_for_level(1) - 1
	var ups := Leveling.grant_xp(c, below)
	assert_eq(ups, 0)
	assert_eq(c.level, 1)
	assert_eq(c.experience, below)

func test_grant_xp_knight_levelup_applies_class_growth():
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	c.hp_max = 30; c.hp = 5
	c.sp_max = 0; c.sp = 0
	c.might = 16; c.endurance = 18; c.intellect = 8
	var ups := Leveling.grant_xp(c, Leveling.xp_for_level(1))   # 剛好 1 級
	assert_eq(ups, 1)
	assert_eq(c.level, 2)
	assert_eq(c.hp_max, 36)        # +6
	assert_eq(c.might, 17)         # +1
	assert_eq(c.endurance, 19)     # +1
	assert_eq(c.intellect, 8)      # 不長
	assert_eq(c.hp, 36)            # 升級回滿

func test_grant_xp_sorcerer_grows_intellect_and_sp():
	var c := Character.new()
	c.char_class = "Sorcerer"
	c.level = 1
	c.hp_max = 14; c.sp_max = 16; c.intellect = 17
	Leveling.grant_xp(c, Leveling.xp_for_level(1))
	assert_eq(c.intellect, 18)     # +1
	assert_eq(c.sp_max, 19)        # +3
	assert_eq(c.hp_max, 16)        # +2

func test_grant_xp_multiple_levelups():
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	var two: int = Leveling.xp_for_level(1) + Leveling.xp_for_level(2)
	var ups := Leveling.grant_xp(c, two)
	assert_eq(ups, 2)
	assert_eq(c.level, 3)
	assert_eq(c.experience, 0)

func test_grant_xp_uncapped_past_100():
	# 玩家等級無上限：給超大 XP 應升遠超 100
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	var huge := 0
	for L in range(1, 130):
		huge += Leveling.xp_for_level(L)
	Leveling.grant_xp(c, huge)
	assert_gt(c.level, 100, "玩家等級不應被卡在 100")
