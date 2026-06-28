class_name MonsterLayer
extends Node3D

# 大地圖會走動的怪 billboard 層。鏡射 ObjectLayer/ChestLayer：跟著切地圖由 main.gd rebuild。
# 腳貼地與尺寸共用 CombatStage 的常數/static，確保和戰鬥裡同大小、同腳踩地板。
# idle 生命感：有第二幀(idle2)的怪走「兩幀輪播」假動畫；沒有的退回「微幅左右晃動」。
const MOVE_TIME := 0.18   # 移動補間時長（對齊玩家步速 feel；不像素測）
const SWAY_WORLD := 0.04    # idle 左右晃動世界振幅（微幅，比照 CombatStage IDLE_AMP 等級）
const SWAY_PERIOD := 1.8    # idle 晃動週期（秒）
const PHASE_SPREAD := 1.7   # 每隻相位間隔（弧度）→ 一群怪不同手同腳
const FRAME_PERIOD := 0.4   # idle 兩幀假動畫單幀顯示時長（秒）；一輪 ~0.8s

var _sprites: Dictionary = {}    # uid -> Sprite3D
var _phase: Dictionary = {}      # uid -> float（idle 晃動/輪播相位）
var _frames: Dictionary = {}     # uid -> {a: Texture2D, b: Texture2D|null}（b 為 null 則退回晃動）
var _cur_frame: Dictionary = {}  # uid -> int（目前顯示幀 0/1，避免每幀重設貼圖）

# 純函式：idle 左右晃動的 billboard offset.x（像素，本地平面）。
# 以 SWAY_WORLD 世界振幅 / pixel_size 換算成像素 → 任何貼圖尺寸都呈現相同世界振幅；
# offset 在 billboard 本地平面 → 永遠讀作螢幕左右（與相機朝向無關），且與 position 獨立（不擾移動補間）。
static func sway_offset_px(t: float, phase: float, sway_world: float, period: float, pixel_size: float) -> float:
	return (sway_world / max(pixel_size, 0.0001)) * sin(t * TAU / period + phase)

# 純函式：兩幀假動畫的幀索引（0/1）。每 period 秒切換；beat_offset（拍）每怪錯開避免同步。
static func frame_index(t: float, beat_offset: float, period: float) -> int:
	return int(floor(t / max(period, 0.0001) + beat_offset)) % 2

func rebuild(monsters: Array) -> void:
	_clear()
	for i in monsters.size():
		var m: Dictionary = monsters[i]
		var fr := _frames_for(m["group"])
		var s := Sprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_apply_texture(s, fr["a"])
		s.position = _world_pos(m["cell"])
		add_child(s)
		_sprites[m["uid"]] = s
		_frames[m["uid"]] = fr
		_phase[m["uid"]] = i * PHASE_SPREAD
		_cur_frame[m["uid"]] = 0
	set_process(not _sprites.is_empty())   # idle 動畫常駐（有怪才開）

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

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for uid in _sprites:
		if not is_instance_valid(_sprites[uid]):
			continue
		_update_frame(uid, t)

# 有第二幀（idle2）→ 兩幀輪播；否則 → 微幅左右晃動 fallback。兩者與 position 獨立，不擾移動補間。
func _update_frame(uid: String, t: float) -> void:
	var s: Sprite3D = _sprites[uid]
	var fr: Dictionary = _frames[uid]
	if fr["b"] != null:
		var idx := frame_index(t, _phase.get(uid, 0.0) / TAU, FRAME_PERIOD)
		if idx != _cur_frame.get(uid, -1):
			_apply_texture(s, fr["b"] if idx == 1 else fr["a"])
			_cur_frame[uid] = idx
	else:
		s.offset = Vector2(sway_offset_px(t, _phase.get(uid, 0.0), SWAY_WORLD, SWAY_PERIOD, s.pixel_size), 0.0)

func _world_pos(cell: Vector2i) -> Vector3:
	return GridGeometry.cell_to_world(cell) + Vector3(0.0, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0)

# 代表兩幀：群組第 0 隻的 idle(真圖/placeholder)=a、idle2=b（可 null）。
func _frames_for(group_key: String) -> Dictionary:
	var ph := _placeholder(Color(0.8, 0.3, 0.3))
	var defs := Bestiary.group_defs_for(group_key)
	if defs.is_empty():
		return {"a": ph, "b": null}
	var t = MonsterSpriteCatalog.textures_for(defs[0].id)
	var a = t["idle"] if t["idle"] != null else ph
	return {"a": a, "b": t.get("idle2", null)}

# 設貼圖並依其高度正規化 pixel_size（換幀不變大小、腳貼地不變）。
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
	_phase.clear()
	_frames.clear()
	_cur_frame.clear()
	set_process(false)
