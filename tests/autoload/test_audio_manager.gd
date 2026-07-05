extends GutTest

const AM := preload("res://autoload/audio_manager.gd")

const TEST_CFG := "user://test_audio_settings.cfg"

func after_each() -> void:
	var abs := ProjectSettings.globalize_path(TEST_CFG)
	if FileAccess.file_exists(TEST_CFG):
		DirAccess.remove_absolute(abs)

func _mgr():
	var m = AM.new()
	add_child_autofree(m)
	return m

func _mgr_with_cfg():
	var m = AM.new()
	m._settings_path = TEST_CFG
	add_child_autofree(m)
	return m

func test_play_map_bgm_sets_track() -> void:
	var m = _mgr()
	m.play_map_bgm("oak_wild")
	assert_eq(m.current_track_id(), "oak_wild")

func test_same_track_noop_keeps_playing_state() -> void:
	var m = _mgr()
	m.play_map_bgm("oak_wild")
	m.play_map_bgm("oak_wild")
	assert_eq(m.current_track_id(), "oak_wild")

func test_combat_push_pop_restores_map_track() -> void:
	var m = _mgr()
	m.play_map_bgm("oak_town")
	m.push_combat_bgm()
	assert_true(m.is_combat_music())
	assert_eq(m.current_track_id(), "combat")
	m.pop_combat_bgm()
	assert_false(m.is_combat_music())
	assert_eq(m.current_track_id(), "oak_town")

func test_map_bgm_during_combat_defers_until_pop() -> void:
	var m = _mgr()
	m.play_map_bgm("oak_town")
	m.push_combat_bgm()
	m.play_map_bgm("oak_wild")
	assert_eq(m.current_track_id(), "combat")
	m.pop_combat_bgm()
	assert_eq(m.current_track_id(), "oak_wild")

func test_stop_music_clears_state() -> void:
	var m = _mgr()
	m.play_map_bgm("oak_wild")
	m.push_combat_bgm()
	m.stop_music()
	assert_eq(m.current_track_id(), "")
	assert_false(m.is_combat_music())

func test_unknown_ids_do_not_crash() -> void:
	var m = _mgr()
	m.play_map_bgm("nope")
	m.play_sfx("nope")
	assert_eq(m.current_track_id(), "nope")

func test_rapid_double_switch_keeps_music_playing() -> void:
	var m = _mgr()
	m.play_map_bgm("oak_town")
	m.play_map_bgm("oak_wild")  # 換圖切曲：播放中的 player 開始淡出（帶 stop callback）
	m.push_combat_bgm()  # crossfade 視窗內第二次切換：重用淡出中的 player 當 incoming
	await wait_seconds(1.3)  # 讓殘留淡出 tween 跑完
	assert_eq(m.current_track_id(), "combat")
	assert_true(m._active.playing, "殘留淡出 tween 不得停掉新啟用的 player")

func test_volume_default_and_set_clamped() -> void:
	var m = _mgr_with_cfg()
	assert_eq(m.volume("Music"), 1.0)
	m.set_volume("Music", 1.5)
	assert_eq(m.volume("Music"), 1.0)
	m.set_volume("Music", -0.2)
	assert_eq(m.volume("Music"), 0.0)

func test_volume_persists_across_instances() -> void:
	var m = _mgr_with_cfg()
	m.set_volume("SFX", 0.25)
	var m2 = _mgr_with_cfg()
	assert_almost_eq(m2.volume("SFX"), 0.25, 0.001)
