extends GutTest

func _inv_with(ids: Array) -> Inventory:
	var inv := Inventory.new()
	for id in ids:
		inv.add_instance(UniqueCatalog.make(id))
	return inv

func test_owned_count_dedup_and_filter():
	var inv := _inv_with(["eternal_lamp", "eternal_lamp", "choir_crown"])
	inv.add_instance(UniqueCatalog.make("dawnblade"))   # 一般 unique 不計
	assert_eq(ArtifactSet.owned_count(inv, null), 2)

func test_incomplete_and_complete():
	var six := ["eternal_lamp", "genesis_casket", "stasis_reliquary",
		"wayfinder_astrolabe", "starender_blade", "choir_crown"]
	assert_false(ArtifactSet.is_complete(_inv_with(six), null))
	assert_true(ArtifactSet.is_complete(_inv_with(six + ["aegis_field_core"]), null))

func test_set_bonus_shape():
	var b := ArtifactSet.set_bonus()
	assert_true(b.size() >= 1)
