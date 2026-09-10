class_name NpcLayer
extends Node3D

# 每位 NPC 一個腳底定位的 root，內含立繪、接觸陰影與靠近提示。
# 註冊素材採固定腳底呼吸；缺素材仍使用開發用 placeholder。
const BREATH_AMOUNT := 0.003
const BREATH_PERIOD := 4.2
const SHADOW_SHADER := preload("res://presentation/world/npc_contact_shadow.gdshader")

var interaction_enabled := true

# member 同時保存 root、立繪、兩幀素材、尺寸、腳底基準與提示。
var _sprites: Array = []

func build(quest_givers: Array) -> void:
	_clear()
	var phase_seed := 0
	for q in quest_givers:
		var fr := _frames_for(String(q.get("sprite", "")))
		var spec := NpcSpriteCatalog.presentation_for(String(q.get("sprite", "")))
		_sprites.append(_make_sprite(fr["a"], fr["b"], q["pos"], phase_seed, spec))
		phase_seed += 1
	set_process(not _sprites.is_empty())   # idle 動畫常駐（有 NPC 才開）

# 從 WorldGrid.regions()（[{map, ox, oy}]）收集所有 region（焦點+鄰圖）的 questgiver，
# 算成全域 cell 的渲染清單，與 OverworldMonsters.init_from_regions 的 region→global 慣例一致。
static func collect(regions: Array) -> Array:
	var out: Array = []
	for region in regions:
		var off := Vector2i(int(region["ox"]), int(region["oy"]))
		var m: MapData = region["map"]
		for q in m.quest_givers:
			out.append({"pos": q["pos"] + off, "sprite": String(q.get("sprite", ""))})
	return out

func _make_sprite(a: Texture2D, b, cell: Vector2i, phase_seed: int, spec: Dictionary) -> Dictionary:
	var anchor := Node3D.new()
	anchor.position = GridGeometry.cell_to_world(cell)
	add_child(anchor)
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(s)
	var height := float(spec.get("height", CombatStage.DISPLAY_HEIGHT))
	var foot := float(spec.get("foot_ratio", 1.0))
	var member := {"root": anchor, "node": s, "a": a, "b": b, "phase": phase_seed * MonsterLayer.PHASE_SPREAD, "cur": 0, "height": height, "foot": foot, "label": null, "authored": not spec.is_empty()}
	_apply_texture(s, a, height)
	s.position.y = height * (foot - 0.5)
	if not spec.is_empty():
		var shadow := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var width := float(spec.get("shadow_width", 0.9))
		quad.size = Vector2(width, width * 0.65)
		shadow.mesh = quad
		shadow.rotation.x = -PI / 2.0
		shadow.position.y = 0.012
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = SHADOW_SHADER
		shadow.material_override = material
		anchor.add_child(shadow)
		var label := Label3D.new()
		label.text = "%s · %s\n[空白鍵] 交談" % [spec["name"], spec["role"]]
		label.position.y = height + 0.17
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		label.pixel_size = 0.0025
		label.modulate = Color(1.0, 0.91, 0.7)
		label.outline_modulate = Color(0.12, 0.09, 0.05)
		label.visible = false
		anchor.add_child(label)
		member["label"] = label
	return member

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for member in _sprites:
		if is_instance_valid(member["node"]):
			_update_member(member, t)
			_update_label(member)

# 僅同高度平面的一格距離、正前方才提示；Label3D 保留深度測試。
static func is_in_focus(origin: Vector3, forward: Vector3, target: Vector3) -> bool:
	var delta := target - origin
	delta.y = 0.0
	forward.y = 0.0
	return delta.length() >= GridGeometry.CELL_SIZE * 0.75 and delta.length() <= GridGeometry.CELL_SIZE * 1.15 and forward.normalized().dot(delta.normalized()) > 0.98

func _update_label(member: Dictionary) -> void:
	var label: Label3D = member["label"]
	if label == null:
		return
	var camera := get_viewport().get_camera_3d()
	label.visible = interaction_enabled and camera != null and is_in_focus(camera.global_position, -camera.global_basis.z, member["root"].global_position)

# 有第二幀則輪播；單張正式素材呼吸；未註冊 placeholder 保留左右晃動。
func _update_member(member: Dictionary, t: float) -> void:
	var s: Sprite3D = member["node"]
	if member["b"] != null:
		var idx := MonsterLayer.frame_index(t, member["phase"] / TAU, MonsterLayer.FRAME_PERIOD)
		if idx != member["cur"]:
			_apply_texture(s, member["b"] if idx == 1 else member["a"], member["height"])
			member["cur"] = idx
	elif member["authored"]:
		# 以已校準的腳底為縮放錨點，底部透明留白不會造成浮空。
		s.scale.y = 1.0 + BREATH_AMOUNT * sin(t * TAU / BREATH_PERIOD + float(member["phase"]))
		s.position.y = float(member["height"]) * (float(member["foot"]) - 0.5) * s.scale.y
	else:
		s.offset = Vector2(MonsterLayer.sway_offset_px(t, member["phase"], MonsterLayer.SWAY_WORLD, MonsterLayer.SWAY_PERIOD, s.pixel_size), 0.0)

# 某 sprite id 的兩幀：idle(真圖/placeholder)=a、idle2=b（可 null → 退回晃動）。
func _frames_for(sprite_id: String) -> Dictionary:
	var ph := _placeholder(Color(0.45, 0.55, 0.75))   # 中性藍灰（與怪物紅方塊區隔）
	var tx = NpcSpriteCatalog.textures_for(sprite_id)
	var a = tx["idle"] if tx["idle"] != null else ph
	return {"a": a, "b": tx.get("idle2", null)}

func _apply_texture(s: Sprite3D, tex: Texture2D, height: float) -> void:
	s.texture = tex
	s.pixel_size = CombatStage.pixel_size_for(tex, height)

func _placeholder(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_sprites.clear()
