class_name CombatStage
extends Node3D

# 戰鬥怪物 3D billboard（placeholder 純色貼圖，真美術另案）。掛在相機前方一排。
# 名牌/血條/狀態/編號改由 2D EnemyPanel 呈現；本元件只管 billboard 與受擊紅閃。
const FLASH_MS := 250

var _camera: Camera3D
var _sprites: Dictionary = {}     # Monster -> Sprite3D
var _flash_until: Dictionary = {} # Sprite3D -> msec

func setup(camera: Camera3D) -> void:
	_camera = camera

func rebuild(monsters: Array) -> void:
	clear()
	var n := monsters.size()
	for i in n:
		var s := Sprite3D.new()
		s.texture = _placeholder(Color(0.8, 0.3, 0.3))
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.02
		_camera.add_child(s)
		var spread := (i - (n - 1) / 2.0) * 1.6
		s.position = Vector3(spread, 0.0, -4.0)
		_sprites[monsters[i]] = s
	refresh()

func refresh() -> void:
	for mon in _sprites:
		_sprites[mon].visible = mon.is_alive()

func flash(monster) -> void:
	if not _sprites.has(monster):
		return
	var s: Sprite3D = _sprites[monster]
	s.modulate = Color(1.6, 0.6, 0.6)
	_flash_until[s] = Time.get_ticks_msec() + FLASH_MS
	set_process(true)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var any := false
	for s in _flash_until:
		if now < _flash_until[s]:
			any = true
		elif is_instance_valid(s):
			s.modulate = Color(1, 1, 1)
	if not any:
		set_process(false)

func clear() -> void:
	for mon in _sprites:
		if is_instance_valid(_sprites[mon]):
			_sprites[mon].queue_free()
	_sprites.clear()
	_flash_until.clear()

func _placeholder(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
