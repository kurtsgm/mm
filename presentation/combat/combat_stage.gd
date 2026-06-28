class_name CombatStage
extends Node3D

# 戰鬥怪物 3D billboard（placeholder 純色貼圖，真美術另案）。掛在相機前方一排。
# 名牌/血條/狀態/編號改由 2D EnemyPanel 呈現；本元件只管 billboard 與受擊紅閃。
const FLASH_MS := 250
const IDLE_PERIOD := 2.0
const IDLE_AMP := 0.03
const LUNGE_DIST := 0.5
const LUNGE_OUT := 0.18
const LUNGE_BACK := 0.22
const ATTACK_SCALE := 1.15
const HIT_MS := 220
const HIT_AMP := 0.06
const DISPLAY_HEIGHT := 2.0   # billboard 目標世界高度（unit）；pixel_size 依貼圖實際高度正規化到此
const _STATE_TEXTURE_KEY := {"idle": "idle", "attack": "attack", "hit": "hurt"}

var _camera: Camera3D
var _sprites: Dictionary = {}     # Monster -> Sprite3D
var _flash_until: Dictionary = {} # Sprite3D -> msec
var _base_pos: Dictionary = {} # Sprite3D -> Vector3（建構排位，所有位移以此為基準）
var _textures: Dictionary = {} # Sprite3D -> {idle,attack,hurt,base}
var _anim: Dictionary = {}     # Sprite3D -> "idle"|"attack"|"hit"
var _tween: Dictionary = {}    # Sprite3D -> Tween（attack/hit 動畫用）
var _feet_y: float = 0.0       # billboard 腳貼地的 y（setup 時依相機眼高算；rebuild 用它定位）

func setup(camera: Camera3D) -> void:
	_camera = camera
	_feet_y = feet_offset(_camera.position.y, DISPLAY_HEIGHT)

func rebuild(monsters: Array) -> void:
	clear()
	var n := monsters.size()
	for i in n:
		var s := Sprite3D.new()
		var t := MonsterSpriteCatalog.textures_for(monsters[i].monster_id)
		# base = idle 真圖優先，否則純色 placeholder（缺 attack/hurt 時回退到 idle 而非紅塊）
		var base_tex := base_texture(t["idle"], _placeholder(Color(0.8, 0.3, 0.3)))
		var textures := {"idle": t["idle"], "attack": t["attack"], "hurt": t["hurt"], "base": base_tex}
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_apply_texture(s, texture_for_state("idle", textures))   # 設貼圖 + 依高度正規化 pixel_size（解析度無關）
		_camera.add_child(s)
		var spread := (i - (n - 1) / 2.0) * 1.6
		s.position = Vector3(spread, _feet_y, -4.0)
		_sprites[monsters[i]] = s
		_base_pos[s] = s.position
		_textures[s] = textures
		_anim[s] = "idle"
	refresh()
	set_process(true)   # idle 呼吸常駐（有 sprite 即開）

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
	# 受擊抖動（hit 優先，打斷 attack）
	_kill_tween(s)
	s.scale = Vector3.ONE   # 打斷攻擊撲擊時可能仍放大(~1.15×)，受擊抖動期間先還原為常態尺寸
	_anim[s] = "hit"
	_apply_texture(s, texture_for_state("hit", _textures[s]))
	var base: Vector3 = _base_pos[s]
	var step := (HIT_MS / 1000.0) / 4.0
	var tw := create_tween()
	tw.tween_property(s, "position", base + Vector3(HIT_AMP, 0.0, 0.0), step)
	tw.tween_property(s, "position", base - Vector3(HIT_AMP, 0.0, 0.0), step)
	tw.tween_property(s, "position", base + Vector3(HIT_AMP * 0.5, 0.0, 0.0), step)
	tw.tween_property(s, "position", base, step)
	tw.tween_callback(Callable(self, "_end_anim").bind(s))
	_tween[s] = tw

func play_attack(monster) -> void:
	if not _sprites.has(monster):
		return
	var s: Sprite3D = _sprites[monster]
	_kill_tween(s)
	_anim[s] = "attack"
	_apply_texture(s, texture_for_state("attack", _textures[s]))
	var base: Vector3 = _base_pos[s]
	var lunged := base + Vector3(0.0, 0.0, LUNGE_DIST)   # local +Z 朝隊伍前撲
	var tw := create_tween()
	tw.tween_property(s, "position", lunged, LUNGE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "scale", Vector3.ONE * ATTACK_SCALE, LUNGE_OUT)
	tw.tween_property(s, "position", base, LUNGE_BACK).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "scale", Vector3.ONE, LUNGE_BACK)
	tw.tween_callback(Callable(self, "_end_anim").bind(s))
	_tween[s] = tw

func _end_anim(s) -> void:
	if not is_instance_valid(s):
		return
	_anim[s] = "idle"
	s.position = _base_pos[s]
	s.scale = Vector3.ONE
	_apply_texture(s, texture_for_state("idle", _textures[s]))
	_tween.erase(s)

func _kill_tween(s) -> void:
	if _tween.has(s) and _tween[s] != null and _tween[s].is_valid():
		_tween[s].kill()
	_tween.erase(s)

# 設貼圖並依其高度正規化 pixel_size。idle/attack/hurt 換圖都走這裡，
# 萬一某怪三態尺寸不一也不會在切換時「大小跳一下」。
func _apply_texture(s: Sprite3D, tex: Texture2D) -> void:
	s.texture = tex
	s.pixel_size = pixel_size_for(tex, DISPLAY_HEIGHT)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var t := now / 1000.0
	for mon in _sprites:
		var s: Sprite3D = _sprites[mon]
		if not is_instance_valid(s):
			continue
		# 紅閃 tint 衰減
		if _flash_until.has(s) and now >= _flash_until[s]:
			s.modulate = Color(1, 1, 1)
			_flash_until.erase(s)
		# idle 呼吸：僅存活且 idle 態
		if mon.is_alive() and _anim.get(s, "idle") == "idle":
			s.position.y = _base_pos[s].y + sin(t * TAU / IDLE_PERIOD) * IDLE_AMP

func clear() -> void:
	for s in _tween:
		if _tween[s] != null and _tween[s].is_valid():
			_tween[s].kill()
	for mon in _sprites:
		if is_instance_valid(_sprites[mon]):
			_sprites[mon].queue_free()
	_sprites.clear()
	_flash_until.clear()
	_base_pos.clear()
	_textures.clear()
	_anim.clear()
	_tween.clear()
	set_process(false)

# 純函式：依動畫態挑該用哪張貼圖；缺該態（null/缺鍵）或不認得的 state → base。
static func texture_for_state(state: String, textures: Dictionary) -> Texture2D:
	var key = _STATE_TEXTURE_KEY.get(state, "")
	var tex = textures.get(key, null)
	if tex == null:
		tex = textures.get("base", null)
	return tex

# 純函式：base 貼圖 = 有 idle 真圖就用 idle，否則用 placeholder（讓缺態回退到真圖而非純色塊）。
static func base_texture(idle_tex, placeholder: Texture2D) -> Texture2D:
	return idle_tex if idle_tex != null else placeholder

# 純函式：解析度無關的 pixel_size——讓任何高度的貼圖都顯示成 display_height 個世界單位高。
static func pixel_size_for(tex: Texture2D, display_height: float) -> float:
	var h := tex.get_height() if tex != null else 0
	return display_height / max(1.0, float(h))

# 純函式：billboard 腳貼地的相對 y。billboard 中心需在地板上方 display_height/2；
# 戰鬥 sprite 掛在相機下（相對座標），故相對 y = display_height/2 − 相機眼高。
static func feet_offset(camera_eye_height: float, display_height: float) -> float:
	return display_height / 2.0 - camera_eye_height

func _placeholder(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
