class_name MonsterLayer
extends Node3D

# 大地圖會走動的怪 billboard 層。鏡射 ObjectLayer/ChestLayer：跟著切地圖由 main.gd rebuild。
# 腳貼地與尺寸共用 CombatStage 的常數/static，確保和戰鬥裡同大小、同腳踩地板。
const MOVE_TIME := 0.18   # 移動補間時長（對齊玩家步速 feel；不像素測）

var _sprites: Dictionary = {}   # uid -> Sprite3D

func rebuild(monsters: Array) -> void:
	_clear()
	for m in monsters:
		var s := Sprite3D.new()
		var tex := _texture_for(m["group"])
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture = tex
		s.pixel_size = CombatStage.pixel_size_for(tex, CombatStage.DISPLAY_HEIGHT)
		s.position = _world_pos(m["cell"])
		add_child(s)
		_sprites[m["uid"]] = s

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
