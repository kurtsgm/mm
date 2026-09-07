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

func test_skin_weights_and_inverse_binds_cover_every_vertex():
	var model := _model()
	assert_eq(model.skeleton.get_bone_count(), 45)
	var blended := 0
	var valid := true
	var bind_valid := true
	for mesh in model._meshes:
		assert_not_null(mesh.skin)
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bone_ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		assert_eq(weights.size(), vertices.size()*4)
		for i in vertices.size():
			var total := 0.0
			var influences := 0
			for slot in 4:
				var weight := weights[i*4+slot]
				total += weight
				valid = valid and weight >= 0.0 and bone_ids[i*4+slot] < model.skeleton.get_bone_count()
				if weight > 0.001: influences += 1
			valid = valid and absf(total-1.0)<0.0001
			if influences > 1: blended += 1
		for i in mesh.skin.get_bind_count():
			var bone_index := mesh.skin.get_bind_bone(i)
			if bone_index < 0:
				bone_index = model.skeleton.find_bone(mesh.skin.get_bind_name(i))
			var restored := model.skeleton.get_bone_global_rest(bone_index)*mesh.skin.get_bind_pose(i)
			bind_valid = bind_valid and restored.is_equal_approx(Transform3D.IDENTITY)
	assert_true(valid, "所有頂點權重必須正規化且指向有效骨骼")
	assert_true(bind_valid, "inverse bind 必須還原綁定姿勢")
	assert_gt(blended, 1000, "關節具真正漸變蒙皮，不只是單骨剛性綁定")

func test_baked_clips_move_bones_and_keep_other_instances_independent():
	var a := _model()
	var b := _model()
	for clip in ["idle","walk","attack","hit"]:
		assert_true(a.animation_player.has_animation(clip))
	var arm := a.skeleton.find_bone("upper_arm_R")
	a.play_attack()
	a._process(0.2)
	assert_ne(a.skeleton.get_bone_pose_rotation(arm), Quaternion.IDENTITY)
	assert_eq(b.skeleton.get_bone_pose_rotation(arm), Quaternion.IDENTITY)
	a.play_hit()
	a.play_attack()
	assert_eq(a.animation, "hit")
	a._process(MonsterModel.HIT_DURATION+0.01)
	a.walk_for(1.0)
	a._process(0.1)
	assert_eq(a.animation_player.current_animation, "walk")
	a._process(1.1)
	assert_eq(a.animation_player.current_animation, "idle")
	assert_eq(a.position, Vector3.ZERO)

func test_elbow_vertices_deform_with_both_arm_bones():
	var model := _model()
	model.set_process(false)
	var mesh := model.skeleton.get_node("Mossskin") as MeshInstance3D
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var candidate := -1
	var upper := model.skeleton.find_bone("upper_arm_R")
	var lower := model.skeleton.find_bone("forearm_R")
	for i in vertices.size():
		var influenced_by: Array[int] = []
		for slot in 4:
			if weights[i*4+slot] < 0.1: continue
			var bind := ids[i*4+slot]
			var bone_index := model.skeleton.find_bone(mesh.skin.get_bind_name(bind))
			if bone_index < 0: bone_index = mesh.skin.get_bind_bone(bind)
			influenced_by.append(bone_index)
		if upper in influenced_by and lower in influenced_by and vertices[i].distance_to(model.skeleton.get_bone_global_rest(lower).origin)>0.05:
			candidate = i
			break
	assert_ne(candidate, -1, "手肘附近有跨骨權重的頂點")
	if candidate < 0: return
	var rest := vertices[candidate]
	model.skeleton.set_bone_pose_rotation(model.skeleton.find_bone("forearm_R"),Quaternion(Vector3.RIGHT, -0.8))
	var deformed := Vector3.ZERO
	for slot in 4:
		var bind := ids[candidate*4+slot]
		var bone_index := model.skeleton.find_bone(mesh.skin.get_bind_name(bind))
		if bone_index < 0: bone_index = mesh.skin.get_bind_bone(bind)
		deformed += (model.skeleton.get_bone_global_pose(bone_index)*mesh.skin.get_bind_pose(bind)*rest)*weights[candidate*4+slot]
	assert_gt(deformed.distance_to(rest),0.001,"實際蒙皮後頂點移動，不只有骨架線在動")
	assert_lt(deformed.distance_to(rest),0.2,"手肘變形保持局部，沒有錯誤 bind 造成爆點")
