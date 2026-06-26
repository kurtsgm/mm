extends GutTest

func test_missing_quest_returns_null():
	assert_null(QuestCatalog.load_quest("___nope___"))
