extends GutTest

func _monster(n: String, hp: int) -> Monster:
	var m := Monster.new()
	m.name = n; m.hp = hp; m.hp_max = hp; m.might = 1; m.armor = 0
	m.accuracy = 1; m.speed = 1; m.xp_reward = 1; m.gold_reward = 1
	return m

func _stage_with(monsters: Array) -> CombatStage:
	var cam := Camera3D.new()
	add_child_autofree(cam)
	var st := CombatStage.new()
	add_child_autofree(st)
	st.setup(cam)
	st.rebuild(monsters)
	return st

func _tex(c: Color) -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func test_rebuild_spawns_one_sprite_per_monster():
	var a := _monster("A", 10); var b := _monster("B", 10)
	var st := _stage_with([a, b])
	assert_eq(st._sprites.size(), 2)

func test_refresh_hides_dead():
	var a := _monster("A", 10); var b := _monster("B", 10)
	var st := _stage_with([a, b])
	b.hp = 0
	st.refresh()
	assert_false(st._sprites[b].visible, "死亡怪物 billboard 隱藏")
	assert_true(st._sprites[a].visible)

func test_flash_marks_sprite_tint():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.flash(a)
	assert_gt(st._sprites[a].modulate.r, 1.0, "受擊紅閃：modulate 提亮")

func test_texture_for_state_picks_per_state():
	var base := _tex(Color.GRAY)
	var idle := _tex(Color.GREEN)
	var atk := _tex(Color.RED)
	var hurt := _tex(Color.BLUE)
	var t := {"idle": idle, "attack": atk, "hurt": hurt, "base": base}
	assert_eq(CombatStage.texture_for_state("idle", t), idle)
	assert_eq(CombatStage.texture_for_state("attack", t), atk)
	assert_eq(CombatStage.texture_for_state("hit", t), hurt, "hit 態用 hurt 貼圖")

func test_texture_for_state_falls_back_to_base():
	var base := _tex(Color.GRAY)
	var t := {"idle": null, "attack": null, "hurt": null, "base": base}
	assert_eq(CombatStage.texture_for_state("idle", t), base, "缺該態 → base")
	assert_eq(CombatStage.texture_for_state("attack", t), base)
	assert_eq(CombatStage.texture_for_state("hit", t), base)
	assert_eq(CombatStage.texture_for_state("???", t), base, "不認得的 state → base")

func test_rebuild_initializes_anim_state_fields():
	var a := _monster("A", 10); var b := _monster("B", 10)
	var st := _stage_with([a, b])
	var sa: Sprite3D = st._sprites[a]
	assert_eq(st._anim[sa], "idle", "初始動畫態 idle")
	assert_true(st._base_pos.has(sa), "存基準位")
	assert_true(st._textures[sa].has("base"), "有 base 貼圖")
	assert_not_null(st._textures[sa]["base"], "base 為 placeholder，非 null")
	assert_eq(sa.texture, st._textures[sa]["base"], "空 catalog → idle 回退 base 貼圖")

func test_clear_empties_anim_fields():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.clear()
	assert_eq(st._base_pos.size(), 0)
	assert_eq(st._textures.size(), 0)
	assert_eq(st._anim.size(), 0)

func test_idle_processing_enabled_after_rebuild():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	assert_true(st.is_processing(), "有怪 → idle 呼吸常駐 _process")

func test_idle_keeps_position_within_amplitude():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	var sa: Sprite3D = st._sprites[a]
	var base_y: float = st._base_pos[sa].y
	st._process(0.016)   # 直接驅動一幀，不 crash
	var dy: float = abs(sa.position.y - base_y)
	assert_true(dy <= st.IDLE_AMP + 0.0001, "idle 位移不超過振幅（sin 有界）")

func test_idle_skips_dead_monster():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	var sa: Sprite3D = st._sprites[a]
	a.hp = 0
	st.refresh()
	var y_before: float = sa.position.y
	st._process(0.016)
	assert_eq(sa.position.y, y_before, "死亡怪不參與 idle 呼吸")

func test_play_attack_sets_attack_state_and_texture():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.play_attack(a)
	var sa: Sprite3D = st._sprites[a]
	assert_eq(st._anim[sa], "attack", "進入 attack 態")
	# 空 catalog → attack 貼圖回退 base
	assert_eq(sa.texture, st._textures[sa]["base"])

func test_play_attack_missing_monster_no_crash():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	var ghost := _monster("Ghost", 10)   # 不在 stage 內
	st.play_attack(ghost)                 # 應安靜 return
	assert_eq(st._anim.size(), 1, "未替不存在的怪建立狀態")

func test_play_attack_reentry_no_crash():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.play_attack(a)
	st.play_attack(a)   # 重入應 kill 舊 tween 不 crash
	assert_eq(st._anim[st._sprites[a]], "attack")

func test_flash_enters_hit_state_and_hurt_texture():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.flash(a)
	var sa: Sprite3D = st._sprites[a]
	assert_eq(st._anim[sa], "hit", "受擊進入 hit 態")
	assert_eq(sa.texture, st._textures[sa]["base"], "空 catalog → hurt 回退 base")
	assert_gt(sa.modulate.r, 1.0, "仍保留紅閃")

func test_flash_overrides_attack():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.play_attack(a)
	st.flash(a)   # 受擊打斷前撲
	assert_eq(st._anim[st._sprites[a]], "hit")

func test_flash_missing_monster_no_crash():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	var ghost := _monster("Ghost", 10)
	st.flash(ghost)   # 不存在 → 安靜 return
	assert_eq(st._anim.size(), 1)

# ---- 真美術接通：base 回退 idle + 依貼圖尺寸正規化顯示高度 ----

func _tex_tall(h: int) -> Texture2D:
	var img := Image.create(2, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.GREEN)
	return ImageTexture.create_from_image(img)

func _goblin_monster() -> Monster:
	var m := _monster("Goblin", 10)
	m.monster_id = "goblin"
	return m

func test_base_texture_prefers_idle():
	var idle := _tex(Color.GREEN)
	var ph := _tex(Color.RED)
	assert_eq(CombatStage.base_texture(idle, ph), idle, "有 idle 真圖 → base 用 idle")

func test_base_texture_falls_back_to_placeholder():
	var ph := _tex(Color.RED)
	assert_eq(CombatStage.base_texture(null, ph), ph, "無 idle → base 用 placeholder")

func test_pixel_size_normalizes_by_height():
	assert_almost_eq(CombatStage.pixel_size_for(_tex_tall(1000), 2.0), 0.002, 0.0001, "1000px 高 → 2.0/1000")
	assert_almost_eq(CombatStage.pixel_size_for(_tex_tall(100), 2.0), 0.02, 0.0001, "100px 高 → 2.0/100")

func test_pixel_size_null_safe():
	assert_eq(CombatStage.pixel_size_for(null, 2.0), 2.0, "null → 除以 1，不 crash")

func test_rebuild_goblin_uses_idle_texture_and_normalized_size():
	var g := _goblin_monster()
	var st := _stage_with([g])
	var s: Sprite3D = st._sprites[g]
	var idle: Texture2D = MonsterSpriteCatalog.textures_for("goblin")["idle"]
	assert_eq(s.texture, idle, "初始顯示 goblin idle 真圖")
	assert_eq(st._textures[s]["base"], idle, "缺態回退 idle 真圖（非紅塊 placeholder）")
	assert_almost_eq(s.pixel_size, CombatStage.pixel_size_for(idle, CombatStage.DISPLAY_HEIGHT), 0.0001, "pixel_size 依貼圖高度正規化")
