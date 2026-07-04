extends GutTest

func test_equipment_bases_only_droppable():
	var bases := LootPool.equipment_bases()
	for d in bases:
		assert_true(d.drop_weight > 0)
