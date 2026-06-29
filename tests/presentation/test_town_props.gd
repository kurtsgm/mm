extends GutTest

# 參數化建築外觀 + 室內家具 prop 的 smoke 測試：能解析、實例化、且 _ready 生出視覺子節點（無 script error）。

func test_each_interior_prop_resolves_and_instantiates():
	for kind in ["counter", "shelf", "barrel", "crate", "table", "brazier", "anvil", "altar", "bookshelf", "bed"]:
		var id: String = "prop_" + String(kind)
		var scene := DecorationCatalog.get_scene(id)
		assert_not_null(scene, "%s 應可由約定式解析" % id)
		if scene == null:
			continue
		var inst = scene.instantiate()
		add_child_autofree(inst)
		assert_true(inst is Node3D, "%s 根節點應為 Node3D" % id)
		assert_gt(inst.get_child_count(), 0, "%s 應生出視覺子節點" % id)

func test_building_exterior_builds_for_each_facing():
	var script := load("res://presentation/world/town_building_ext.gd")
	for facing in ["N", "E", "S", "W"]:
		var n := Node3D.new()
		n.set_script(script)
		n.set("w", 2)
		n.set("h", 2)
		n.set("door_dx", 0)
		n.set("door_dy", 0)
		n.set("facing", facing)
		add_child_autofree(n)   # 觸發 _ready 建牆/屋頂/招牌
		assert_gt(n.get_child_count(), 0, "facing=%s 應生出子節點" % facing)

func test_building_exterior_3x2_with_offset_door():
	var script := load("res://presentation/world/town_building_ext.gd")
	var n := Node3D.new()
	n.set_script(script)
	n.set("w", 3)
	n.set("h", 2)
	n.set("door_dx", 1)
	n.set("door_dy", 1)
	n.set("facing", "S")
	add_child_autofree(n)
	assert_gt(n.get_child_count(), 0)
