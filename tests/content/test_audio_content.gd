extends GutTest

const TRACK_IDS := ["oak_wild", "oak_town", "interior", "combat"]
const SFX_IDS := ["hit", "victory", "defeat", "chest", "menu_open", "menu_close", "dialogue", "levelup"]

func test_all_track_paths_exist() -> void:
	for id in TRACK_IDS:
		var e := AudioCatalog.track_entry(id)
		assert_false(e.is_empty(), "缺 track: " + id)
		assert_true(ResourceLoader.exists(String(e["path"])), "track 檔不存在: " + id)

func test_all_sfx_paths_exist() -> void:
	for id in SFX_IDS:
		var e := AudioCatalog.sfx_entry(id)
		assert_false(e.is_empty(), "缺 sfx: " + id)
		assert_true(ResourceLoader.exists(String(e["path"])), "sfx 檔不存在: " + id)

func test_every_map_bgm_registered() -> void:
	for path in DirAccess.get_files_at("res://content/maps"):
		if not path.ends_with(".json"):
			continue
		var f := FileAccess.open("res://content/maps/" + path, FileAccess.READ)
		var m := MapImporter.parse(f.get_as_text())
		assert_ne(m.bgm, "", path + " 缺 bgm")
		assert_false(AudioCatalog.track_entry(m.bgm).is_empty(), path + " bgm 未註冊: " + m.bgm)
