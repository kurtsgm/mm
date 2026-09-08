extends GutTest

func _model() -> MonsterModel:
	var model := MonsterModelCatalog.instantiate("poison_spider")
	add_child_autofree(model)
	model.set_process(false)
	return model

func test_spider_is_small_volumetric_and_faces_are_outward():
	var model := _model()
	var bounds := AABB()
	var first := true
	var inward := 0
	var total := 0
	for mesh in model._meshes:
		assert_true(mesh.mesh.surface_get_material(0).vertex_color_use_as_albedo,"頂點彩繪斑紋匯入後仍可見")
		bounds = mesh.get_aabb() if first else bounds.merge(mesh.get_aabb())
		first = false
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			var a := indices[i]
			var b := indices[i+1]
			var c := indices[i+2]
			var cross_value := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
			if cross_value.length_squared()<0.00000000000001: continue
			# Godot clockwise winding must oppose the outward vertex normals.
			if cross_value.dot(normals[a]+normals[b]+normals[c])>0.0: inward += 1
			total += 1
	assert_eq(inward,0,"甲殼、眼球與細毛外表面不可反面剔除")
	assert_gt(total,50000,"離線細節網格已匯入")
	assert_between(bounds.size.y,0.60,0.72,"低矮小體型，保留物種比例")
	assert_lt(bounds.size.y,MonsterModel.HEIGHT*0.4)
	assert_between(bounds.size.x,1.4,1.7)
	assert_between(bounds.size.z,1.5,1.8)
	assert_almost_eq(bounds.position.y,0.0,0.003,"腳尖原點貼地")

func test_segmented_skin_and_inverse_binds_are_valid():
	var model := _model()
	assert_eq(model.skeleton.get_bone_count(),41)
	var valid := true
	var valid_binds := true
	for mesh in model._meshes:
		assert_not_null(mesh.skin)
		var arrays := mesh.mesh.surface_get_arrays(0)
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		assert_eq(weights.size(),arrays[Mesh.ARRAY_VERTEX].size()*4)
		for i in range(0,weights.size(),4):
			var sum := 0.0
			for slot in 4:
				sum += weights[i+slot]
				valid = valid and weights[i+slot]>=0.0 and ids[i+slot]>=0 and ids[i+slot]<mesh.skin.get_bind_count()
			valid = valid and absf(sum-1.0)<0.0001
		for i in mesh.skin.get_bind_count():
			var bone := model.skeleton.find_bone(mesh.skin.get_bind_name(i))
			if bone<0: bone = mesh.skin.get_bind_bone(i)
			valid_binds = valid_binds and (model.skeleton.get_bone_global_rest(bone)*mesh.skin.get_bind_pose(i)).is_equal_approx(Transform3D.IDENTITY)
	assert_true(valid,"硬質外骨骼分節綁定，所有頂點權重有效")
	assert_true(valid_binds,"inverse bind 保持模型原姿勢")

func _pose(model: MonsterModel, clip: String, fraction: float) -> void:
	model.animation_player.play(clip)
	model.animation_player.seek(model.animation_player.get_animation(clip).length*fraction,true)
	model.animation_player.advance(0)

func test_idle_contacts_and_alternating_walk_clear_the_ground():
	var model := _model()
	var grounded := true
	var lifts := 0
	var length_valid := true
	for clip in ["idle","walk","attack","hit"]:
		for sample in 11:
			_pose(model,clip,float(sample)/10.0)
			for side in ["L","R"]:
				for pair in range(1,5):
					var suffix: String = side+str(pair)
					var foot := model.skeleton.get_bone_global_pose(model.skeleton.find_bone("foot_"+suffix)).origin
					grounded = grounded and foot.y>=0.002
					if clip=="idle": grounded = grounded and absf(foot.y-0.004)<0.002
					if clip=="walk" and foot.y>0.04: lifts += 1
					for segment in ["tibia_","tarsus_","foot_"]:
						var id := model.skeleton.find_bone(segment+suffix)
						length_valid = length_valid and absf(model.skeleton.get_bone_pose_position(id).length()-model.skeleton.get_bone_rest(id).origin.length())<0.002
	assert_true(grounded,"待機腳尖固定，所有動作腳尖不穿地")
	assert_gt(lifts,16,"爬行有多次抬足")
	assert_true(length_valid,"IK 烘焙保持各段肢體長度")
	for clip in ["idle","walk"]:
		_pose(model,clip,0)
		var start: Array[Transform3D] = []
		for i in model.skeleton.get_bone_count(): start.append(model.skeleton.get_bone_global_pose(i))
		_pose(model,clip,1)
		var seamless := true
		for i in model.skeleton.get_bone_count(): seamless = seamless and start[i].is_equal_approx(model.skeleton.get_bone_global_pose(i))
		assert_true(seamless,clip+" 首尾姿勢一致")

func test_attack_deforms_fangs_and_instances_keep_independent_hit_state():
	var a := _model()
	var b := _model()
	assert_same(a._meshes[0].mesh,b._meshes[0].mesh)
	var fang := a.skeleton.find_bone("fang_L")
	_pose(a,"attack",0.4)
	assert_ne(a.skeleton.get_bone_pose_rotation(fang),Quaternion.IDENTITY)
	assert_eq(b.skeleton.get_bone_pose_rotation(fang),Quaternion.IDENTITY)
	a.play_hit()
	a.play_attack()
	assert_eq(a.animation,"hit")
	assert_null(b._meshes[0].material_overlay)
	a._process(MonsterModel.HIT_DURATION+0.01)
	assert_eq(a.animation,"idle")
	assert_null(a._meshes[0].material_overlay)
	assert_eq(a.position,Vector3.ZERO)

func test_existing_spider_encounters_use_grounded_3d_members():
	var layer := MonsterLayer.new()
	add_child_autofree(layer)
	layer.rebuild([{"uid":"spiders","cell":Vector2i(2,3),"group":"ps","state":0}])
	assert_eq(layer._sprites["spiders"].size(),2)
	for member in layer._sprites["spiders"]:
		assert_true(member.node is MonsterModel)
		assert_almost_eq(member.node.position.y,0.0,0.0001)
	layer.apply_moves([{"uid":"spiders","cell":Vector2i(3,3)}])
	for member in layer._sprites["spiders"]:
		member.node._process(0.05)
		assert_eq(member.node.animation_player.current_animation,"walk")

func test_spider_and_goblin_share_combat_with_natural_scale():
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.position.y = 1.6
	var stage := CombatStage.new()
	add_child_autofree(stage)
	stage.setup(camera)
	var spider := Monster.new()
	spider.monster_id = "poison_spider"
	spider.hp = 10
	var goblin := Monster.new()
	goblin.monster_id = "goblin"
	goblin.hp = 10
	stage.rebuild([spider,goblin])
	for monster in [spider,goblin]:
		assert_true(stage._sprites[monster] is MonsterModel)
		assert_almost_eq(stage._sprites[monster].global_position.y,0.0,0.0001)
		assert_eq(stage._sprites[monster].scale,Vector3.ONE)
	stage.play_attack(spider)
	assert_eq(stage._sprites[spider].animation,"attack")
	stage.flash(spider)
	assert_eq(stage._sprites[spider].animation,"hit")
	assert_eq(stage._sprites[goblin].animation,"idle")
	stage.clear()
