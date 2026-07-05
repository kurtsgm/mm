extends GutTest

const DIR := "res://tests/presentation/cutscene/_tmp"

func before_all():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

func _write(id: String, text: String) -> void:
	var f := FileAccess.open("%s/%s.json" % [DIR, id], FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_load_valid():
	_write("okcs", '{"id":"okcs","steps":[{"type":"wait","duration":1.0}]}')
	var d := CutsceneCatalog.load_from("%s/okcs.json" % DIR)
	assert_not_null(d)
	assert_eq(d.id, "okcs")

func test_missing_file_returns_null():
	assert_null(CutsceneCatalog.load_from("%s/nope.json" % DIR))

func test_malformed_json_returns_null():
	_write("bad", "{ not json")
	assert_null(CutsceneCatalog.load_from("%s/bad.json" % DIR))
