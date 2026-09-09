extends GutTest

func _model() -> MonsterModel:
	var model := MonsterModelCatalog.instantiate("ogre")
	add_child_autofree(model)
	model.set_process(false)
	return model

func _pose(model: MonsterModel, clip: String, fraction: float) -> void:
	model.animation_player.play(clip)
	model.animation_player.seek(model.animation_player.get_animation(clip).length * fraction, true)
	model.animation_player.advance(0)

func _deform(model: MonsterModel, mesh: MeshInstance3D) -> PackedVector3Array:
	var a := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var ids: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var transforms: Array[Transform3D] = []
	for i in mesh.skin.get_bind_count():
		var bone := model.skeleton.find_bone(mesh.skin.get_bind_name(i))
		transforms.append(model.skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(i))
	var result := PackedVector3Array()
	for i in vertices.size():
		var p := Vector3.ZERO
		for slot in 4:
			p += (transforms[ids[i * 4 + slot]] * vertices[i]) * weights[i * 4 + slot]
		result.append(p)
	return result

func test_heavy_human_scale_and_colored_pbr_survive_export():
	var model := _model()
	var bounds := AABB()
	for mesh in model._meshes:
		bounds = bounds.merge(mesh.get_aabb())
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		assert_true(material.vertex_color_use_as_albedo)
		var colors: PackedColorArray = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var mean := Color(0, 0, 0, 0)
		for color in colors:
			mean += color / colors.size()
		assert_lt(mean.r, 0.85, "Tint 必須匯出到 COLOR_0，不能誤取白色遮罩：" + str(mesh.name))
		if str(mesh.name).begins_with("Skin"):
			assert_not_null(material.albedo_texture)
			assert_not_null(material.normal_texture)
	assert_between(bounds.size.y, 3.08, 3.22)
	assert_almost_eq(bounds.position.y, 0.0, 0.012)
	assert_eq(model.skeleton.get_bone_count(), 23)

func test_attack_does_not_pin_inner_forearm_to_torso():
	var model := _model()
	var mesh := model._meshes[0]
	var a := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var largest := 0.0
	for fraction in [0.2, 0.34, 0.4, 0.55, 0.7]:
		_pose(model, "attack", fraction)
		var posed := _deform(model, mesh)
		for t in range(0, indices.size(), 3):
			for slot in 3:
				var i := indices[t + slot]
				var j := indices[t + (slot + 1) % 3]
				var length := vertices[i].distance_to(vertices[j])
				if length > 0.01:
					largest = maxf(largest, posed[i].distance_to(posed[j]) / length)
	assert_lt(largest, 4.0, "舉槌時皮膚邊長不應被拉成軀幹到前臂的長條")

func test_walk_keeps_contact_foot_grounded_and_lifts_swing_foot():
	var model := _model()
	var min_floor := INF
	var max_lift := 0.0
	for frame in 25:
		_pose(model, "walk", frame / 24.0)
		var heights: Array[float] = []
		for side in ["L", "R"]:
			var bone := model.skeleton.find_bone("foot_" + side)
			var delta := model.skeleton.get_bone_global_pose(bone).origin.y - model.skeleton.get_bone_global_rest(bone).origin.y
			heights.append(delta)
			max_lift = maxf(max_lift, delta)
			min_floor = minf(min_floor, delta)
		assert_almost_eq(minf(heights[0], heights[1]), 0.0, 0.006, "每個時點至少一腳承重")
	assert_gte(min_floor, -0.006)
	assert_gt(max_lift, 0.075)
	assert_eq(model.position, Vector3.ZERO)

func test_stone_maul_is_rigidly_bound_to_right_hand():
	var model := _model()
	var found := false
	for mesh in model._meshes:
		if not str(mesh.name).begins_with("Stone"):
			continue
		found = true
		var a := mesh.mesh.surface_get_arrays(0)
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var ids: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var valid := true
		for i in weights.size():
			if weights[i] > 0:
				valid = valid and mesh.skin.get_bind_name(ids[i]) == &"hand_R" and is_equal_approx(weights[i], 1.0)
		assert_true(valid, "槌頭完整跟隨手掌，不受軀幹或裙甲權重影響")
		_pose(model, "RESET", 0)
		var rest := _deform(model, mesh)
		_pose(model, "attack", 0.34)
		var raised := _deform(model, mesh)
		assert_gt(raised[0].distance_to(rest[0]), 1.0)
		assert_almost_eq(rest[0].distance_to(rest[20]), raised[0].distance_to(raised[20]), 0.0001)
	assert_true(found)

func test_existing_ogre_encounter_borrows_same_world_model_in_combat():
	var layer := MonsterLayer.new()
	add_child_autofree(layer)
	layer.rebuild([{"uid": "ogre-test", "group": "o", "cell": Vector2i(11, 10), "state": 0}])
	var members: Array = layer._sprites["ogre-test"]
	assert_eq(members.size(), 1)
	var model: MonsterModel = members[0].node
	var origin := model.position
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var stage := CombatStage.new()
	add_child_autofree(stage)
	stage.setup(camera)
	var group := EncounterSystem.build_group(Bestiary.group_defs_for("o"))
	stage.bind_existing(group, members, layer._update_member)
	assert_same(stage._sprites[group[0]], model)
	stage.play_attack(group[0])
	model._process(0.2)
	assert_eq(model.animation, "attack")
	stage.flash(group[0])
	assert_eq(model.animation, "hit")
	model._process(MonsterModel.HIT_DURATION + 0.01)
	assert_eq(model.animation, "idle")
	assert_eq(model.position, origin)
	stage.clear()
	assert_same(model.get_parent(), layer, "離開戰鬥仍由大地圖保有同一模型")
