extends GutTest

func test_load_demo_event():
	var d := DialogueCatalog.load_dialogue("demo_event")
	assert_not_null(d)
	assert_eq(d.start, "root")
	assert_true(d.has_node("bought"))

func test_missing_dialogue_returns_null():
	assert_null(DialogueCatalog.load_dialogue("does_not_exist"))
