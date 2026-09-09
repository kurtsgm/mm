extends GutTest

const Validator = preload("res://tools/monster_asset_validator.gd")

func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/monsters/asset_manifest.json"))

func _model(id: String) -> MonsterModel:
	var model := MonsterModelCatalog.instantiate(id)
	add_child_autofree(model)
	model.set_process(false)
	return model

func _surface() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	return arrays

func _local_animation(model: MonsterModel, clip: String) -> Animation:
	var library := model.animation_player.get_animation_library("").duplicate(true) as AnimationLibrary
	model.animation_player.remove_animation_library("")
	model.animation_player.add_animation_library("", library)
	return model.animation_player.get_animation(clip)

func test_all_registered_assets_meet_shared_contract() -> void:
	var manifest := _manifest()
	var covered: Array[String] = []
	for spec in manifest.monsters:
		covered.append(spec.id)
		var result := Validator.inspect(_model(spec.id), spec, manifest.budgets)
		assert_eq(result.errors, [], "%s: %s" % [spec.id, result.errors])
		assert_gt(result.metrics.triangles, 0)
	for id in MonsterModelCatalog._MODELS:
		assert_has(covered, id, "Every registered 3D species needs an asset manifest entry")

func test_surface_rejects_bad_indices_and_nonfinite_geometry() -> void:
	var arrays := _surface()
	assert_eq(Validator.check_surface(arrays, 1), [])
	arrays[Mesh.ARRAY_INDEX][2] = 3
	assert_has(Validator.check_surface(arrays, 1), "index outside vertex array")
	arrays[Mesh.ARRAY_INDEX][2] = -1
	assert_has(Validator.check_surface(arrays, 1), "index outside vertex array")
	arrays[Mesh.ARRAY_VERTEX][0] = Vector3(NAN, 0, 0)
	assert_has(Validator.check_surface(arrays, 1), "non-finite vertex")

func test_surface_rejects_malformed_and_invalid_skin_weights() -> void:
	var arrays := _surface()
	arrays[Mesh.ARRAY_WEIGHTS][0] = 0.5
	assert_true(str(Validator.check_surface(arrays, 1)).contains("unnormalized"))
	arrays[Mesh.ARRAY_WEIGHTS][0] = NAN
	assert_true(str(Validator.check_surface(arrays, 1)).contains("invalid weight"))
	arrays = _surface()
	arrays[Mesh.ARRAY_BONES][0] = -1
	assert_true(str(Validator.check_surface(arrays, 1)).contains("bind index"))
	arrays[Mesh.ARRAY_BONES][0] = 1
	assert_true(str(Validator.check_surface(arrays, 1)).contains("bind index"))
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	assert_has(Validator.check_surface(arrays, 1), "missing or malformed skin arrays")

func test_loop_seam_is_detected_even_with_looping_enabled() -> void:
	var model := _model("goblin")
	var animation := _local_animation(model, "idle")
	var track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track, NodePath("Skeleton3D:head"))
	var rest := model.skeleton.get_bone_rest(model.skeleton.find_bone("head")).origin
	animation.position_track_insert_key(track, 0.0, rest)
	animation.position_track_insert_key(track, animation.length, rest + Vector3(0, 0.1, 0))
	var errors: Array[String] = []
	Validator._check_animations(model, _manifest().monsters[0], errors)
	assert_true(str(errors).contains("loop endpoints differ"), str(errors))
	assert_eq(animation.loop_mode, Animation.LOOP_LINEAR, "Validator restores imported animation settings")

func test_anchor_motion_and_wrong_runtime_duration_are_rejected() -> void:
	var model := _model("goblin")
	var animation := _local_animation(model, "attack")
	animation.length = 1.0
	var track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track, NodePath("."))
	animation.position_track_insert_key(track, 0.0, Vector3.ZERO)
	animation.position_track_insert_key(track, 1.0, Vector3.RIGHT)
	var errors: Array[String] = []
	Validator._check_animations(model, _manifest().monsters[0], errors)
	assert_true(str(errors).contains("animation moves world anchor"), str(errors))
	assert_true(str(errors).contains("length differs from runtime driver"), str(errors))
	assert_eq(model.position, Vector3.ZERO)

func test_imported_idle_and_walk_keep_playing_past_first_cycle() -> void:
	for spec in _manifest().monsters:
		var model := _model(spec.id)
		for clip in ["idle", "walk"]:
			var animation := model.animation_player.get_animation(clip)
			assert_eq(animation.loop_mode, Animation.LOOP_LINEAR)
			model.animation_player.play(clip)
			model.animation_player.advance(animation.length + 0.15)
			assert_true(model.animation_player.is_playing(), spec.id + "/" + clip)
			assert_almost_eq(model.animation_player.current_animation_position, 0.15, 0.002)

func test_draft_budgets_report_overages_without_hiding_technical_results() -> void:
	var warnings := Validator.budget_warnings({"triangles": 51, "bones": 4}, {"triangles": 50, "materials": 8, "texture_edge": 1024, "bones": 4, "glb_mib": 10})
	assert_eq(warnings.size(), 1)
	assert_true(warnings[0].begins_with("triangles:"))
