extends GutTest

const AM := preload("res://autoload/audio_manager.gd")

func _mgr():
	var m = AM.new()
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
