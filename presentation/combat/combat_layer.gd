class_name CombatLayer
extends CanvasLayer

# 程式建構的 placeholder 戰鬥畫面（無真美術）：
# - 怪物 2D billboard（Sprite3D，掛在相機前方，placeholder 純色貼圖）
# - 行動選單：[1-9] 攻擊對應敵人 / [D] 防禦 / [F] 逃跑
# - 戰鬥 log（最近數行）
# 逐回合驅動 CombatSystem；玩家行動後自動結算怪物回合到下個隊員回合或戰鬥結束。

signal combat_finished(result: int)

var combat: CombatSystem

var _camera: Camera3D
var _sprites: Array[Sprite3D] = []
var _prompt_label: Label
var _log_label: Label
var _log_lines: Array[String] = []

func begin(cs: CombatSystem, camera: Camera3D) -> void:
	combat = cs
	_camera = camera
	_build_ui()
	_spawn_billboards()
	_log_lines.clear()
	_push_log("戰鬥開始！")
	set_process_unhandled_input(true)
	_resolve()  # 怪物若較快先動

func _build_ui() -> void:
	if _prompt_label == null:
		_prompt_label = Label.new()
		_prompt_label.position = Vector2(40, 40)
		_prompt_label.add_theme_font_size_override("font_size", 20)
		add_child(_prompt_label)
	if _log_label == null:
		_log_label = Label.new()
		_log_label.position = Vector2(40, 100)
		_log_label.add_theme_font_size_override("font_size", 16)
		add_child(_log_label)
	_prompt_label.text = ""
	_log_label.text = ""

func _spawn_billboards() -> void:
	var living := combat.living_monsters()
	var n := living.size()
	for i in n:
		var s := Sprite3D.new()
		s.texture = _placeholder_texture(Color(0.8, 0.3, 0.3))
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.02
		_camera.add_child(s)
		var spread := (i - (n - 1) / 2.0) * 1.6
		s.position = Vector3(spread, 0.0, -4.0)
		_sprites.append(s)

func _placeholder_texture(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _unhandled_input(event: InputEvent) -> void:
	if combat == null or not combat.is_party_turn():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var living := combat.living_monsters()
	var key: int = event.keycode
	if key >= KEY_1 and key <= KEY_9:
		var idx := key - KEY_1
		if idx < living.size():
			_apply(combat.party_attack(idx))
	elif key == KEY_D:
		_apply(combat.party_defend())
	elif key == KEY_F:
		_apply(combat.party_run())

func _apply(events: Array) -> void:
	for e in events:
		_push_log(e)
	_resolve()

# 自動結算怪物回合，直到輪到隊員或戰鬥結束
func _resolve() -> void:
	while not combat.is_over() and not combat.is_party_turn():
		for e in combat.monster_act():
			_push_log(e)
	if combat.is_over():
		_finish()
	else:
		_refresh_prompt()

func _refresh_prompt() -> void:
	var actor = combat.current_combatant()
	var text := "%s 的回合 — [1-9] 攻擊 / [D] 防禦 / [F] 逃跑\n敵人：" % actor.name
	var living := combat.living_monsters()
	for i in living.size():
		text += "  %d.%s(HP %d)" % [i + 1, living[i].name, maxi(living[i].hp, 0)]
	_prompt_label.text = text

func _push_log(text: String) -> void:
	_log_lines.append(text)
	while _log_lines.size() > 8:
		_log_lines.remove_at(0)
	_log_label.text = "\n".join(_log_lines)

func _finish() -> void:
	var result := combat.result()
	_prompt_label.text = ""
	for s in _sprites:
		s.queue_free()
	_sprites.clear()
	combat = null
	set_process_unhandled_input(false)
	combat_finished.emit(result)
