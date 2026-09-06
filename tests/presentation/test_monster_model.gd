extends GutTest

func _model() -> MonsterModel:
	var model := MonsterModelCatalog.instantiate("goblin")
	add_child_autofree(model)
	return model

func test_unknown_species_has_no_model():
	assert_null(MonsterModelCatalog.instantiate("unknown"))
	assert_false(MonsterModelCatalog.has_model("ogre"))

func test_baked_geometry_has_volume_and_all_vertices_are_drawn():
	var model := _model()
	var bounds := AABB()
	var first := true
	for mesh in model._meshes:
		var transform := model.global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var used: Dictionary = {}
		for index in indices:
			used[index] = true
		assert_eq(used.size(), arrays[Mesh.ARRAY_VERTEX].size(), "合併網格不可漏掉耳朵/刀刃等未索引來源：" + str(mesh.name))
	assert_gt(bounds.size.z, 0.5, "真正有厚度的模型")
	assert_almost_eq(bounds.position.y, 0.0, 0.002, "靜止時鞋底落在模型原點")
	assert_almost_eq(bounds.end.y, MonsterModel.HEIGHT, 0.03, "符合遊戲顯示高度")

func test_hit_material_is_local_but_baked_meshes_are_shared():
	var a := _model()
	var b := _model()
	assert_same(a._meshes[0].mesh, b._meshes[0].mesh, "多隻怪共用資產")
	a.play_hit()
	a._process(0.1)
	assert_not_null(a._meshes[0].material_overlay)
	assert_null(b._meshes[0].material_overlay, "受擊不影響其他怪")
	a._process(MonsterModel.HIT_DURATION)
	assert_null(a._meshes[0].material_overlay)

func test_attack_completes_and_repeated_attack_can_restart():
	var model := _model()
	model.play_attack()
	model._process(0.2)
	model.play_attack()
	assert_eq(model._elapsed, 0.0)
	model._process(MonsterModel.ATTACK_DURATION + 0.01)
	assert_eq(model.animation, "idle")
	assert_eq(model.position, Vector3.ZERO)

func test_hidden_model_pauses_joint_animation():
	var model := _model()
	model.hide()
	model._process(1.0)
	assert_eq(model._clock, 0.0)
