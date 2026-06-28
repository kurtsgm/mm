class_name MonsterLayer
extends Node3D

# 大地圖會走動的怪 billboard 層。鏡射 ObjectLayer/ChestLayer：跟著切地圖由 main.gd rebuild。
# 腳貼地與尺寸共用 CombatStage 的常數/static，確保和戰鬥裡同大小、同腳踩地板。
const MOVE_TIME := 0.18   # 移動補間時長（對齊玩家步速 feel；不像素測）
const SWAY_WORLD := 0.04    # idle 左右晃動世界振幅（微幅，比照 CombatStage IDLE_AMP 等級）
const SWAY_PERIOD := 1.8    # idle 晃動週期（秒）
const PHASE_SPREAD := 1.7   # 每隻相位間隔（弧度）→ 一群怪不同手同腳

var _sprites: Dictionary = {}   # uid -> Sprite3D
var _phase: Dictionary = {}     # uid -> float（idle 晃動相位）

# 純函式：idle 左右晃動的 billboard offset.x（像素，本地平面）。
# 以 SWAY_WORLD 世界振幅 / pixel_size 換算成像素 → 任何貼圖尺寸都呈現相同世界振幅；
# offset 在 billboard 本地平面 → 永遠讀作螢幕左右（與相機朝向無關），且與 position 獨立（不擾移動補間）。
static func sway_offset_px(t: float, phase: float, sway_world: float, period: float, pixel_size: float) -> float:
	return (sway_world / max(pixel_size, 0.0001)) * sin(t * TAU / period + phase)

func rebuild(monsters: Array) -> void:
	_clear()
	for i in monsters.size():
		var m: Dictionary = monsters[i]
		var s := Sprite3D.new()
		var tex := _texture_for(m["group"])
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture = tex
		s.pixel_size = CombatStage.pixel_size_for(tex, CombatStage.DISPLAY_HEIGHT)
		s.position = _world_pos(m["cell"])
		add_child(s)
		_sprites[m["uid"]] = s
		_phase[m["uid"]] = i * PHASE_SPREAD
	set_process(not _sprites.is_empty())   # idle 晃動常駐（有怪才開）

func apply_moves(monsters: Array) -> void:
	for m in monsters:
		var uid: String = m["uid"]
		if not _sprites.has(uid):
			continue
		var s: Sprite3D = _sprites[uid]
		var target := _world_pos(m["cell"])
		if s.position.is_equal_approx(target):
			continue
		var tw := create_tween()
		tw.tween_property(s, "position", target, MOVE_TIME)

# idle 左右微幅晃動：每幀依各自相位設 billboard offset.x（與 position 獨立 → 不擾移動補間）。
func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for uid in _sprites:
		var s: Sprite3D = _sprites[uid]
		if not is_instance_valid(s):
			continue
		s.offset = Vector2(sway_offset_px(t, _phase.get(uid, 0.0), SWAY_WORLD, SWAY_PERIOD, s.pixel_size), 0.0)

func _world_pos(cell: Vector2i) -> Vector3:
	return GridGeometry.cell_to_world(cell) + Vector3(0.0, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0)

# 代表貼圖：群組第 0 隻的 idle 真圖；缺則純色 placeholder（其餘怪暫無真圖）。
func _texture_for(group_key: String) -> Texture2D:
	var defs := Bestiary.group_defs_for(group_key)
	if not defs.is_empty():
		var tex = MonsterSpriteCatalog.textures_for(defs[0].id)["idle"]
		if tex != null:
			return tex
	return _placeholder(Color(0.8, 0.3, 0.3))

func _placeholder(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_sprites.clear()
	_phase.clear()
	set_process(false)
