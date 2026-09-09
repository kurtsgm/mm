extends GutTest

func test_all_registered_content_and_references_are_valid():
	assert_eq(ContentLint.run(), [])

func test_unknown_id_cannot_be_used_as_a_path():
	assert_false(ContentRegistry.has_entry("dialogues", "../maps/wild_ne"))
	assert_eq(ContentRegistry.json_entry("dialogues", "../maps/wild_ne"), {})
	assert_null(ItemCatalog.get_item("missing"))

func test_registry_queries_do_not_expose_mutable_manifest():
	var entry := ContentRegistry.entry("items", "potion")
	entry["path"] = "missing"
	assert_not_null(ItemCatalog.get_item("potion"))

func test_missing_cross_reference_reports_its_source():
	var errors: Array = []
	ContentLint.check_reference("spells", "missing", "vendor/test", errors)
	assert_eq(errors, ["vendor/test: missing spells/missing"])
