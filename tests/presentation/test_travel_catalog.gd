extends GutTest

class FakeState:
	var flags := {}
	func has_flag(f: String) -> bool:
		return flags.has(f)

func test_network_loads_nodes() -> void:
	assert_gt(TravelCatalog.load_network().size(), 0)

func test_node_entry_finds_by_id() -> void:
	var n := TravelCatalog.node_entry("oak_caravan")
	assert_eq(String(n["map"]), "town_oak")

func test_unlocked_excludes_current_and_locked() -> void:
	var s := FakeState.new()
	var ids := []
	for d in TravelCatalog.unlocked_destinations(s, "oak_caravan"):
		ids.append(String(d["id"]))
	assert_does_not_have(ids, "oak_caravan")
	assert_does_not_have(ids, "oak_se_camp")  # 未解鎖不出現

func test_unlocked_includes_after_flag() -> void:
	var s := FakeState.new()
	s.flags["travel_se_camp"] = true
	var ids := []
	for d in TravelCatalog.unlocked_destinations(s, "oak_caravan"):
		ids.append(String(d["id"]))
	assert_has(ids, "oak_se_camp")
