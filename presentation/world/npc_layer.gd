class_name NpcLayer
extends Node3D

# 任務 NPC 的站立 billboard 層。每個 questgiver 一個 Sprite3D，腳貼地、面向鏡頭、原大小（無 cluster）。
# idle 生命感：有 idle2 → 兩幀輪播；否則微幅左右晃動。複用 MonsterLayer 的純函式/常數與 CombatStage 尺寸。
# 跟著切地圖由 main.gd rebuild。NPC 不移動，故無 apply_moves。

# member = { node:Sprite3D, a:Texture2D, b:Texture2D|null, phase:float, cur:int }
var _sprites: Array = []

func build(quest_givers: Array) -> void:
	_clear()
	var phase_seed := 0
	for q in quest_givers:
		var fr := _frames_for(String(q.get("sprite", "")))
		_sprites.append(_make_sprite(fr["a"], fr["b"], q["pos"], phase_seed))
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

func _make_sprite(a: Texture2D, b, cell: Vector2i, phase_seed: int) -> Dictionary:
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_apply_texture(s, a)
	s.position = GridGeometry.cell_to_world(cell) + Vector3(0.0, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0)
	add_child(s)
	return {"node": s, "a": a, "b": b, "phase": phase_seed * MonsterLayer.PHASE_SPREAD, "cur": 0}

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for member in _sprites:
		if is_instance_valid(member["node"]):
			_update_member(member, t)

# 有第二幀（idle2）→ 兩幀輪播；否則 → 微幅左右晃動 fallback。與 position 獨立。
func _update_member(member: Dictionary, t: float) -> void:
	var s: Sprite3D = member["node"]
	if member["b"] != null:
		var idx := MonsterLayer.frame_index(t, member["phase"] / TAU, MonsterLayer.FRAME_PERIOD)
		if idx != member["cur"]:
			_apply_texture(s, member["b"] if idx == 1 else member["a"])
			member["cur"] = idx
	else:
		s.offset = Vector2(MonsterLayer.sway_offset_px(t, member["phase"], MonsterLayer.SWAY_WORLD, MonsterLayer.SWAY_PERIOD, s.pixel_size), 0.0)

# 某 sprite id 的兩幀：idle(真圖/placeholder)=a、idle2=b（可 null → 退回晃動）。
func _frames_for(sprite_id: String) -> Dictionary:
	var ph := _placeholder(Color(0.45, 0.55, 0.75))   # 中性藍灰（與怪物紅方塊區隔）
	var tx = NpcSpriteCatalog.textures_for(sprite_id)
	var a = tx["idle"] if tx["idle"] != null else ph
	return {"a": a, "b": tx.get("idle2", null)}

func _apply_texture(s: Sprite3D, tex: Texture2D) -> void:
	s.texture = tex
	s.pixel_size = CombatStage.pixel_size_for(tex, CombatStage.DISPLAY_HEIGHT)

func _placeholder(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_sprites.clear()
