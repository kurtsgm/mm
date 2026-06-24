extends GutTest

func test_xp_for_level_increases():
	assert_lt(Leveling.xp_for_level(1), Leveling.xp_for_level(2))

func test_grant_xp_no_levelup_below_threshold():
	var c := Character.new()
	c.level = 1
	c.experience = 0
	var ups := Leveling.grant_xp(c, 50)   # 1→2 需 100
	assert_eq(ups, 0)
	assert_eq(c.level, 1)
	assert_eq(c.experience, 50)

func test_grant_xp_single_levelup_bumps_and_restores():
	var c := Character.new()
	c.level = 1
	c.hp = 5
	c.hp_max = 20
	c.sp = 0
	c.sp_max = 10
	var ups := Leveling.grant_xp(c, 100)
	assert_eq(ups, 1)
	assert_eq(c.level, 2)
	assert_eq(c.hp_max, 25)
	assert_eq(c.sp_max, 12)
	assert_eq(c.hp, 25)   # 升級回滿
	assert_eq(c.sp, 12)
	assert_eq(c.experience, 0)

func test_grant_xp_multiple_levelups():
	var c := Character.new()
	c.level = 1
	var ups := Leveling.grant_xp(c, 300)   # 100(1→2) + 200(2→3) = 300
	assert_eq(ups, 2)
	assert_eq(c.level, 3)
	assert_eq(c.experience, 0)
