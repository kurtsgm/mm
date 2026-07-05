extends GutTest

func test_track_entry_known() -> void:
	var e := AudioCatalog.track_entry("combat")
	assert_true(String(e["path"]).begins_with("res://content/audio/"))

func test_track_entry_unknown_returns_empty() -> void:
	assert_true(AudioCatalog.track_entry("nope").is_empty())

func test_sfx_entry_known_and_unknown() -> void:
	assert_false(AudioCatalog.sfx_entry("hit").is_empty())
	assert_true(AudioCatalog.sfx_entry("nope").is_empty())
