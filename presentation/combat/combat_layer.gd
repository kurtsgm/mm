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
var _mode: String = "action"           # "action" | "spell" | "target"
var _spell_list: Array = []            # Array[SpellDef]
var _pending_spell: SpellDef = null

func begin(cs: CombatSystem, camera: Camera3D) -> void:
	combat = cs
	_mode = "action"
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
	var key: int = event.keycode
	match _mode:
		"action": _action_input(key)
		"spell": _spell_input(key)
		"target": _target_input(key)

func _action_input(key: int) -> void:
	var living := combat.living_monsters()
	if key >= KEY_1 and key <= KEY_9:
		var idx := key - KEY_1
		if idx < living.size():
			_apply(combat.party_attack(idx))
	elif key == KEY_D:
		_apply(combat.party_defend())
	elif key == KEY_F:
		_apply(combat.party_run())
	elif key == KEY_C:
		_open_spell_menu()

func _open_spell_menu() -> void:
	var actor = combat.current_combatant()
	_spell_list = []
	for id in actor.known_spells:
		var s := SpellBook.get_spell(id)
		if s != null and s.is_combat_usable():
			_spell_list.append(s)
	if _spell_list.is_empty():
		_push_log("%s 沒有可在戰鬥中施放的法術。" % actor.name)
		return
	_mode = "spell"
	_refresh_spell_prompt()

func _spell_input(key: int) -> void:
	if key == KEY_ESCAPE:
		_mode = "action"; _refresh_prompt(); return
	if key >= KEY_1 and key <= KEY_9:
		var idx := key - KEY_1
		if idx < _spell_list.size():
			_pending_spell = _spell_list[idx]
			var t: int = _pending_spell.target
			if t == SpellDef.Target.ALL_ENEMIES or t == SpellDef.Target.ALL_ALLIES:
				_cast_pending(0)
			else:
				_mode = "target"; _refresh_target_prompt()

func _target_input(key: int) -> void:
	if key == KEY_ESCAPE:
		_mode = "spell"; _refresh_spell_prompt(); return
	if key >= KEY_1 and key <= KEY_9:
		_cast_pending(key - KEY_1)

func _cast_pending(target_index: int) -> void:
	var events := combat.party_cast(_pending_spell, target_index)
	_pending_spell = null
	_mode = "action"
	_apply(events)

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
	var text := "%s 的回合 — [1-9] 攻擊 / [C] 施法 / [D] 防禦 / [F] 逃跑\n敵人：" % actor.name
	var living := combat.living_monsters()
	for i in living.size():
		text += "  %d.%s(HP %d)" % [i + 1, living[i].name, maxi(living[i].hp, 0)]
	_prompt_label.text = text

func _refresh_spell_prompt() -> void:
	var actor = combat.current_combatant()
	var text := "%s 施法 — 數字鍵選法術 / [Esc] 返回\n" % actor.name
	for i in _spell_list.size():
		var s: SpellDef = _spell_list[i]
		text += "  %d.%s(SP%d)" % [i + 1, s.display_name, s.sp_cost]
	_prompt_label.text = text

func _refresh_target_prompt() -> void:
	var text := "選擇目標 — 數字鍵 / [Esc] 返回\n"
	if _pending_spell.target == SpellDef.Target.SINGLE_ALLY:
		var ms := combat.party.members
		for i in ms.size():
			text += "  %d.%s(HP %d/%d)" % [i + 1, ms[i].name, maxi(ms[i].hp, 0), ms[i].hp_max]
	else:
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
