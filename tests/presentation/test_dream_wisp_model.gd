extends GutTest

func _model() -> MonsterModel:
	var model := MonsterModelCatalog.instantiate("dream_wisp")
	add_child_autofree(model)
	model.set_process(false)
	return model

func _pose(model: MonsterModel, clip: String, fraction: float) -> void:
	model.animation_player.play(clip)
	model.animation_player.seek(model.animation_player.get_animation(clip).length*fraction,true)
	model.animation_player.advance(0)

func test_fae_has_small_human_body_and_four_independent_wings():
	var model := _model()
	assert_eq(model.skeleton.get_bone_count(),39)
	var bounds := AABB()
	var first := true
	for mesh in model._meshes:
		bounds=mesh.get_aabb() if first else bounds.merge(mesh.get_aabb())
		first=false
	assert_between(bounds.size.y,0.85,1.05)
	assert_between(bounds.size.x,1.00,1.25)
	assert_almost_eq(bounds.position.y,0.0,0.005)
	for side in ["L","R"]:
		for wing in ["wing_upper_","wing_lower_"]:
			assert_gte(model.skeleton.find_bone(wing+side),0)
	assert_lt(model.skeleton.get_bone_global_rest(model.skeleton.find_bone("head")).origin.y,MonsterModel.HEIGHT*0.5)

func test_geometry_faces_outward_and_materials_keep_surface_detail():
	var model := _model()
	var inward := 0
	var valid := true
	for mesh in model._meshes:
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		assert_true(mesh.mesh.surface_get_material(0).vertex_color_use_as_albedo)
		for i in range(0,indices.size(),3):
			var a:=indices[i]
			var b:=indices[i+1]
			var c:=indices[i+2]
			var cross_value:=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
			if cross_value.length_squared()>0.00000000000001 and cross_value.dot(normals[a]+normals[b]+normals[c])>0: inward+=1
		for p in vertices: valid=valid and p.is_finite()
	assert_eq(inward,0,"皮膚、髮絲與雙面翅膀的表面朝向正確")
	assert_true(valid)
	var skin: MeshInstance3D=model.skeleton.get_node("Skin")
	assert_not_null(skin.mesh.surface_get_material(0).normal_texture,"皮膚微細節內嵌於 GLB")
	assert_eq(skin.mesh.surface_get_material(0).albedo_color,Color.WHITE,"膚色不被重複相乘")
	var wings: MeshInstance3D=model.skeleton.get_node("Wings")
	assert_not_null(wings.mesh.surface_get_material(0).albedo_texture)
	assert_gt(wings.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(),2500)

func test_skin_weights_and_inverse_binds_are_valid():
	var model:=_model()
	var valid:=true
	var bind_valid:=true
	var blended:=0
	for mesh in model._meshes:
		assert_not_null(mesh.skin)
		var a:=mesh.mesh.surface_get_arrays(0)
		var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
		var ids: PackedInt32Array=a[Mesh.ARRAY_BONES]
		assert_eq(weights.size(),a[Mesh.ARRAY_VERTEX].size()*4)
		for i in range(0,weights.size(),4):
			var total:=0.0
			for slot in 4:
				total+=weights[i+slot]
				valid=valid and weights[i+slot]>=0 and ids[i+slot]>=0 and ids[i+slot]<mesh.skin.get_bind_count()
			valid=valid and absf(total-1.0)<0.0001
			if weights[i]>0.01 and weights[i+1]>0.01: blended+=1
		for i in mesh.skin.get_bind_count():
			var bone:=model.skeleton.find_bone(mesh.skin.get_bind_name(i))
			if bone<0: bone=mesh.skin.get_bind_bone(i)
			bind_valid=bind_valid and (model.skeleton.get_bone_global_rest(bone)*mesh.skin.get_bind_pose(i)).is_equal_approx(Transform3D.IDENTITY)
	assert_true(valid)
	assert_true(bind_valid)
	assert_gt(blended,1000,"手肘、膝與軀幹有跨骨權重")

func test_animation_hovers_without_moving_world_anchor_and_loops_seamlessly():
	var model:=_model()
	var above_ground:=true
	for clip in ["idle","walk","attack","hit"]:
		for sample in 11:
			_pose(model,clip,float(sample)/10)
			for side in ["L","R"]:
				var foot:=model.skeleton.get_bone_global_pose(model.skeleton.find_bone("foot_"+side)).origin
				above_ground=above_ground and foot.y>0.11
			assert_eq(model.position,Vector3.ZERO)
	assert_true(above_ground,"動畫腳部保持懸空")
	for clip in ["idle","walk"]:
		_pose(model,clip,0)
		var start: Array[Transform3D]=[]
		for i in model.skeleton.get_bone_count(): start.append(model.skeleton.get_bone_global_pose(i))
		_pose(model,clip,1)
		var seamless:=true
		for i in model.skeleton.get_bone_count(): seamless=seamless and start[i].is_equal_approx(model.skeleton.get_bone_global_pose(i))
		assert_true(seamless,clip+" 首尾無跳動")

func test_wings_and_casting_hand_deform_actual_bound_vertices():
	var model:=_model()
	var wing: MeshInstance3D=model.skeleton.get_node("Wings")
	var arrays:=wing.mesh.surface_get_arrays(0)
	var rest: Vector3=arrays[Mesh.ARRAY_VERTEX][100]
	var bind: int=arrays[Mesh.ARRAY_BONES][400]
	var bone:=model.skeleton.find_bone(wing.skin.get_bind_name(bind))
	if bone<0: bone=wing.skin.get_bind_bone(bind)
	_pose(model,"idle",0.13)
	var deformed:=model.skeleton.get_bone_global_pose(bone)*wing.skin.get_bind_pose(bind)*rest
	assert_gt(deformed.distance_to(rest),0.05,"翼膜頂點跟著骨架實際位移")
	_pose(model,"attack",0.5)
	assert_ne(model.skeleton.get_bone_pose_rotation(model.skeleton.find_bone("upper_arm_L")),Quaternion.IDENTITY)

func test_hit_can_interrupt_cast_and_instances_are_independent():
	var a:=_model()
	var b:=_model()
	assert_same(a._meshes[0].mesh,b._meshes[0].mesh)
	a.play_attack()
	a._process(0.2)
	a.play_hit()
	a.play_attack()
	assert_eq(a.animation,"hit")
	assert_null(b._meshes[0].material_overlay)
	a._process(MonsterModel.HIT_DURATION+0.01)
	assert_eq(a.animation,"idle")
	assert_null(a._meshes[0].material_overlay)

func test_existing_dream_encounter_and_combat_use_3d_fae():
	var layer:=MonsterLayer.new()
	add_child_autofree(layer)
	layer.rebuild([{"uid":"fae","cell":Vector2i(5,5),"group":"dw","state":0}])
	assert_eq(layer._sprites["fae"].size(),2)
	for member in layer._sprites["fae"]: assert_true(member.node is MonsterModel)
	var camera:=Camera3D.new()
	add_child_autofree(camera)
	camera.position.y=1.6
	var stage:=CombatStage.new()
	add_child_autofree(stage)
	stage.setup(camera)
	var monster:=Monster.new()
	monster.monster_id="dream_wisp"
	monster.hp=8
	stage.rebuild([monster])
	assert_true(stage._sprites[monster] is MonsterModel)
	assert_almost_eq(stage._sprites[monster].global_position.y,0.0,0.0001)
	stage.play_attack(monster)
	assert_eq(stage._sprites[monster].animation,"attack")
	stage.flash(monster)
	assert_eq(stage._sprites[monster].animation,"hit")
	stage.clear()

func test_fingertips_follow_hands_and_cast_does_not_stretch_skin_edges():
	var model:=_model()
	var skin: MeshInstance3D=model.skeleton.get_node("Skin")
	var a:=skin.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
	var ids: PackedInt32Array=a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
	_pose(model,"attack",0.5)
	var transforms: Array[Transform3D]=[]
	for bind in skin.skin.get_bind_count():
		var bone:=model.skeleton.find_bone(skin.skin.get_bind_name(bind))
		if bone<0: bone=skin.skin.get_bind_bone(bind)
		transforms.append(model.skeleton.get_bone_global_pose(bone)*skin.skin.get_bind_pose(bind))
	var deformed:=PackedVector3Array()
	var hands_valid:=true
	var fingertips:=0
	for i in vertices.size():
		var p:=Vector3.ZERO
		for slot in 4:
			p+=(transforms[ids[i*4+slot]]*vertices[i])*weights[i*4+slot]
			if absf(vertices[i].x)>0.35*0.494 and vertices[i].y<0.88*0.494 and weights[i*4+slot]>0.01:
				var name:=str(skin.skin.get_bind_name(ids[i*4+slot]))
				hands_valid=hands_valid and (name.begins_with("hand_") or name.begins_with("forearm_"))
		deformed.append(p)
		if absf(vertices[i].x)>0.35*0.494 and vertices[i].y<0.88*0.494: fingertips+=1
	var maximum_stretch:=1.0
	for triangle in range(0,indices.size(),3):
		for edge in 3:
			var ia:=indices[triangle+edge]
			var ib:=indices[triangle+(edge+1)%3]
			var rest_length:=vertices[ia].distance_to(vertices[ib])
			if rest_length>0.001:
				var stretch:=deformed[ia].distance_to(deformed[ib])/rest_length
				maximum_stretch=maxf(maximum_stretch,stretch)
	assert_gt(fingertips,100)
	assert_true(hands_valid,"低於骨盆的指尖仍綁在手部")
	assert_lt(maximum_stretch,4.0,"施法時不能出現跨身體拉長的蒙皮三角形")
