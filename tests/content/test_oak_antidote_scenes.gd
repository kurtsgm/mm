extends GutTest

# 守門：qg_margo 每個節點都有非空 image，且 image 都已登記在 SceneImageCatalog（防漏接/拼錯）。
func test_every_margo_node_has_registered_image():
	var data := DialogueCatalog.load_dialogue("qg_margo")
	assert_not_null(data, "qg_margo 可載入")
	assert_gt(data.nodes.size(), 0, "有節點")
	for nid in data.nodes:
		var img := String(data.nodes[nid].get("image", ""))
		assert_ne(img, "", "節點 %s 有 image" % nid)
		assert_true(SceneImageCatalog.has_image(img), "節點 %s 的 image '%s' 已登記" % [nid, img])

func test_margo_node_image_mapping():
	var data := DialogueCatalog.load_dialogue("qg_margo")
	var want := {
		"root": "margo_clinic", "money": "margo_portrait", "accepted": "marsh_swampherb",
		"nag": "margo_portrait", "turned_in": "margo_clinic", "thanks": "margo_portrait",
	}
	for nid in want:
		assert_eq(String(data.nodes[nid].get("image", "")), want[nid], "節點 %s → %s" % [nid, want[nid]])
